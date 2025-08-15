// TwinMind - An AI chatbot for Second Life
// Written by: Brian Aviator inSL
// MIT License
// This script listens for chat messages beginning with the trigger prefix and responds using Google's Gemini API

// Configuration variables
string CONFIG_NOTECARD = "config";
string API_KEY = "";
string API_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";
string MODEL = "gemini-2.5-flash";
string BOT_NAME = "TwinMind";         // Default Bot name
string TRIGGER_PREFIX = "twin";      // Default trigger prefix
float RATE_LIMIT_SECONDS = 10.0;    // Default minimum time between API calls
integer MAX_TOKENS = 100;           // Default maximum tokens in response
float TEMPERATURE = 0.7;            // Default temperature parameter
integer LISTENING_CHANNEL = 0;      // Public chat channel
integer DEBUG_MODE = FALSE;         // Whether to show debug messages to owner
string SYSTEM_PROMPT = "You are TwinMind, an AI demonstration exhibit in Second Life. Your responses should be brief (75-100 words at most) as they'll appear in public chat. Be helpful, and friendly. Your responses will be visible to everyone in the area, so keep them appropriate for all audiences, G-rated only.";

// Runtime variables
integer config_line;
key config_query_id;
integer listening = TRUE;
integer can_process = TRUE;
float last_request_time = -9999.0;  // Initialize to a large negative value to ensure first request passes
key http_request_id;

// Conversation history variables
list conversation_history = [];     // Stores conversation messages as JSON objects with role and content
list conversation_timestamps = [];  // Stores timestamps for each message (for cleanup)
integer MAX_HISTORY_SIZE = 10;      // Store 5 interactions (user + assistant = 10 messages)
float HISTORY_TIMEOUT = 1200.0;     // 20 minutes in seconds

// Function to convert utf8 encoded strings to Unicode
string utf8ToUnicode(string s)
{
    integer len = llStringLength(s);
    string result = "";
    integer i = 0;
    
    while (i < len)
    {
        integer code = llOrd(s, i);
        integer unicode;
        
        if (code > 240) // 4-byte UTF-8 character
        {
            unicode = (code & 7) * 262144; // 2^18
            i++;
            code = llOrd(s, i);
            unicode += (code & 63) * 4096; // 2^12
            i++;
            code = llOrd(s, i);
            unicode += (code & 63) * 64;   // 2^6
            i++;
            code = llOrd(s, i);
            unicode += (code & 63);
        }
        else if (code > 224) // 3-byte UTF-8 character
        {
            unicode = (code & 15) * 4096;  // 2^12
            i++;
            code = llOrd(s, i);
            unicode += (code & 63) * 64;   // 2^6
            i++;
            code = llOrd(s, i);
            unicode += (code & 63);
        }
        else if (code > 192) // 2-byte UTF-8 character
        {
            unicode = (code & 31) * 64;    // 2^6
            i++;
            code = llOrd(s, i);
            unicode += (code & 63);
        }
        else // 1-byte ASCII character
        {
            unicode = code;
        }
        
        result += llChar(unicode);
        i++;
    }
    
    return result;
}
 
// Function to read configuration from notecard
init() {
    // Reset configuration reading
    config_line = 0;
    
    // Start reading the configuration notecard
    if (llGetInventoryType(CONFIG_NOTECARD) == INVENTORY_NOTECARD) {
        config_query_id = llGetNotecardLine(CONFIG_NOTECARD, config_line);
    } else {
        llOwnerSay("Error: Configuration notecard '" + CONFIG_NOTECARD + "' not found!");
    }
}

// Function to send debug messages to owner if debug mode is enabled
debug(string message) {
    if (DEBUG_MODE) {
        llOwnerSay("DEBUG: " + message);
    }
}

// Function to handle rate limiting
integer checkRateLimit() {
    float current_time = llGetTime();
    if (current_time - last_request_time < RATE_LIMIT_SECONDS) {
        return FALSE;  // Rate limit in effect
    }
    return TRUE;  // OK to proceed
}

// Function to check if sender is an avatar (not an object)
integer isAvatar(key id) {
    return llGetAgentSize(id) != ZERO_VECTOR;
}

// Function to clean up expired history entries
cleanupHistory() {
    float current_time = llGetTime();
    list new_history = [];
    list new_timestamps = [];
    
    integer i;
    for (i = 0; i < llGetListLength(conversation_history); i++) {
        float timestamp = llList2Float(conversation_timestamps, i);
        if (current_time - timestamp < HISTORY_TIMEOUT) {
            // Keep this entry
            new_history += llList2String(conversation_history, i);
            new_timestamps += timestamp;
        }
    }
    
    conversation_history = new_history;
    conversation_timestamps = new_timestamps;
    debug("History cleaned. Entries remaining: " + (string)(llGetListLength(conversation_history) / 2));
}

// Function to add message to conversation history
addToHistory(string role, string content) {
    // Clean up expired entries first
    cleanupHistory();
    // Add new entry as a JSON object with role and parts (array with text)
    string entry = llList2Json(JSON_OBJECT, [
        "role", role,
        "parts", llList2Json(JSON_ARRAY, [llList2Json(JSON_OBJECT, ["text", content])])
    ]);
    conversation_history += entry;
    conversation_timestamps += llGetTime();
    // Trim history if it exceeds maximum size
    while (llGetListLength(conversation_history) > MAX_HISTORY_SIZE) {
        conversation_history = llDeleteSubList(conversation_history, 0, 0);
        conversation_timestamps = llDeleteSubList(conversation_timestamps, 0, 0);
    }
    debug("Added to history. Total entries: " + (string)llGetListLength(conversation_history));
}

// Function to make Gemini API request
makeApiRequest(string user_message, key avatar_id, string avatar_name) {
    // Update rate limiting timestamp
    last_request_time = llGetTime();
    can_process = FALSE;
    // Clean up expired history before building messages
    cleanupHistory();
    // Add system prompt as the first message if not present
    list contents = [];
    contents += llList2Json(JSON_OBJECT, [
        "role", "system",
        "parts", llList2Json(JSON_ARRAY, [llList2Json(JSON_OBJECT, ["text", SYSTEM_PROMPT])])
    ]);
    // Add conversation history
    integer i;
    for (i = 0; i < llGetListLength(conversation_history); i++) {
        contents += llList2String(conversation_history, i);
    }
    // Format and add current user message
    string formatted_user_message = "An avatar in second life named " + avatar_name + " asks: " + user_message;
    addToHistory("user", formatted_user_message);
    contents += llList2Json(JSON_OBJECT, [
        "role", "user",
        "parts", llList2Json(JSON_ARRAY, [llList2Json(JSON_OBJECT, ["text", formatted_user_message])])
    ]);
    // Trim to max history size (including system and new user message)
    while (llGetListLength(contents) > MAX_HISTORY_SIZE + 2) {
        contents = llDeleteSubList(contents, 1, 1); // keep system prompt at index 0
    }
    string contents_array = llList2Json(JSON_ARRAY, contents);
    string generation_config = llList2Json(JSON_OBJECT, [
        "temperature", TEMPERATURE,
        "maxOutputTokens", MAX_TOKENS
    ]);
    // Prepare Gemini API request JSON
    string json = llList2Json(JSON_OBJECT, [
        "contents", contents_array,
        "generationConfig", generation_config
    ]);
    debug("Sending API request: " + json);
    // Set up HTTP headers for Gemini API
    list headers = [];
    headers += [HTTP_METHOD, "POST"];
    headers += [HTTP_MIMETYPE, "application/json"];
    headers += [HTTP_BODY_MAXLENGTH, 16384];
    headers += [HTTP_VERIFY_CERT, FALSE];
    headers += [HTTP_CUSTOM_HEADER, "x-goog-api-key", API_KEY];
    // Make the API request
    http_request_id = llHTTPRequest(API_ENDPOINT, headers, json);
}

// Function to process and send AI response
processAiResponse(string response_json) {
    // Extract the completion from the JSON response
    string content = "";
    
    debug("Received API response: " + response_json);
    
    // Parse the Gemini JSON response to extract the text content
    string text_content = llJsonGetValue(response_json, ["candidates", 0, "content", "parts", 0, "text"]);
    
    if (text_content != JSON_INVALID) {
        content = text_content;
        // Add assistant's response to history
        addToHistory("assistant", content);
    } else {
        // If we couldn't parse the response, provide an error message
        content = "Something went wrong with the Gemini API. Try again later!";
        llOwnerSay("Error parsing JSON response: " + response_json);
    }
    
    // Send the response to public chat (Convert to Unicode for SL)
    llSay(LISTENING_CHANNEL, BOT_NAME + ": " + utf8ToUnicode(content));
    
    // Reset the processing flag after a short delay (to prevent spam)
    llSetTimerEvent(RATE_LIMIT_SECONDS);
}

default {
    state_entry() {
        llOwnerSay(BOT_NAME + " initializing...");
        llResetTime();
        // Clear conversation history on script start
        conversation_history = [];
        conversation_timestamps = [];
        init();
    }
    
    on_rez(integer start_param) {
        llResetScript();
    }
    
    dataserver(key query_id, string data) {
        if (query_id == config_query_id) {
            if (data != EOF) {
                // Process configuration line
                list parts = llParseString2List(data, ["="], []);
                if (llGetListLength(parts) == 2) {
                    string param = llStringTrim(llList2String(parts, 0), STRING_TRIM);
                    string value = llStringTrim(llList2String(parts, 1), STRING_TRIM);
                    
                    if (param == "API_KEY") {
                        API_KEY = value;
                    } else if (param == "MODEL") {
                        MODEL = value;
                    } else if (param == "TRIGGER_PREFIX") {
                        TRIGGER_PREFIX = llToLower(value);
                    } else if (param == "RATE_LIMIT") {
                        RATE_LIMIT_SECONDS = (float)value;
                    } else if (param == "MAX_TOKENS") {
                        MAX_TOKENS = (integer)value;
                    } else if (param == "TEMPERATURE") {
                        TEMPERATURE = (float)value;
                    } else if (param == "DEBUG_MODE") {
                        DEBUG_MODE = (integer)value;
                    } else if (param == "SYSTEM_PROMPT") {
                        SYSTEM_PROMPT = value;
                    } else if (param == "BOT_NAME") {
                        BOT_NAME = value;
                    } else if (param == "API_ENDPOINT") {
                        API_ENDPOINT = value;
                    } else if (param == "LISTENING_CHANNEL") {
                        LISTENING_CHANNEL = (integer)value;
                    } else if (param == "MAX_HISTORY_SIZE") {
                        MAX_HISTORY_SIZE = (integer)value;
                    } else if (param == "HISTORY_TIMEOUT") {
                        HISTORY_TIMEOUT = (float)value;
                    }
                }
                
                // Read next line
                config_line++;
                config_query_id = llGetNotecardLine(CONFIG_NOTECARD, config_line);
            } else {
                // Done reading configuration
                // Update SYSTEM_PROMPT if it contains BOT_NAME placeholder
                if (llSubStringIndex(SYSTEM_PROMPT, "TwinMind") != -1) {
                    SYSTEM_PROMPT = llReplaceSubString(SYSTEM_PROMPT, "TwinMind", BOT_NAME, 0);
                }
                llOwnerSay(BOT_NAME + " configuration loaded.");
                
                // Check if we have a valid API key
                if (API_KEY == "") {
                    llOwnerSay("Error: API_KEY not found in configuration!");
                } else {
                    llOwnerSay(BOT_NAME + " is now active. Chat messages starting with '" + TRIGGER_PREFIX + "' will be processed.");
                    llListen(LISTENING_CHANNEL, "", NULL_KEY, "");
                }
            }
        }
    }
    
    listen(integer channel, string name, key id, string message) {
        // Check if the bot is currently listening
        if (!listening) return;
        
        // Get lowercase message for case-insensitive matching
        string lower_message = llToLower(message);
        integer prefix_length = llStringLength(TRIGGER_PREFIX);
        
        // Check if message starts with the trigger prefix (case insensitive)
        if (llGetSubString(lower_message, 0, prefix_length - 1) == TRIGGER_PREFIX) {
            // Check if sender is an avatar, not an object
            if (!isAvatar(id)) {
                return;
            }
            
            // Check if we're already processing a request
            if (!can_process) {
                llSay(LISTENING_CHANNEL, "Please wait a bit longer between requests!");
                return;
            }
            
            // Check if we can process requests based on rate limit
            if (checkRateLimit()) {
                // Extract the actual query (remove the trigger prefix)
                string query = llStringTrim(llGetSubString(message, prefix_length, -1), STRING_TRIM);
                
                // Process the request if it's not empty
                if (query != "") {
                    makeApiRequest(query, id, name);
                } else {
                    llSay(LISTENING_CHANNEL, "Please ask me something after the '" + TRIGGER_PREFIX + "' command!");
                }
            } else {
                llSay(LISTENING_CHANNEL, " Rate limited. Please wait a moment before asking again!");
            }
        }
    }
    
    http_response(key request_id, integer status, list metadata, string body) {
        if (request_id == http_request_id) {
            if (status == 200) {
                // Successful API response
                processAiResponse(body);
            } else {
                // Error with the API request
                llSay(LISTENING_CHANNEL, "I encountered an error talking to the Gemini API. Status: " + (string)status);
                llOwnerSay("API Error: " + body);
                
                // Reset processing flag with a shorter cooldown for errors
                llSetTimerEvent(2.0);
            }
        }
    }
    
    timer() {
        // Reset the processing flag when the timer fires
        can_process = TRUE;
        llSetTimerEvent(0.0);  // Stop the timer
    }
    
    changed(integer change) {
        if (change & CHANGED_INVENTORY) {
            // Reload configuration if the notecard changes
            if (llGetInventoryType(CONFIG_NOTECARD) == INVENTORY_NOTECARD) {
                init();
            }
        }
    }
    
    touch_start(integer total_number) {
        // Toggle listening when touched by owner
        if (llDetectedKey(0) == llGetOwner()) {
            listening = !listening;
            if (listening) {
                llOwnerSay(BOT_NAME + " is now active.");
            } else {
                llOwnerSay(BOT_NAME + " is now inactive.");
            }
        }
    }
}
