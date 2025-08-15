# TwinMind
Second Life LSL Code for a Google Gemini AI Chat Bot

**Instructions for Configuring the Chat Bot**
---
1. Create an object in second life or use a prefab object.
2. Create a notecard and copy the contents of the config file in this reporsitory to it.
3. Adjust the parameters of the config file as follows:
    - API_KEY=<YOUR_API_KEY>
        - Change <YOUR_API_KEY> to your Google Gemini API Key
        - You can get one at: [Google AI Studio](https://aistudio.google.com/app/apikey)
        - Note: Google offers free daily usage of API keys with limits - beyond that the usage of an API key is not free! By default the script uses gemini-2.5-flash which is very inexpensive once you exceed the free tier. Pricing is available at: [Google AI Pricing](https://ai.google.dev/pricing)
    - MODEL=gemini-2.5-flash
        - This model works well for most purposes and is inexpensive but other Gemini models can be used.
    - TRIGGER_PREFIX=twin
        - This is the prefix to be added in chat to use the bot. The default is "twin" meaning an avatar in range of the bot can type "twin what is Second Life?" to have the bot respond about Second Life.
    - RATE_LIMIT=10.0
        - The number of seconds the user must wait between chat requests. This is to minimize abuse and manage API costs.
    - MAX_TOKENS=1000
        - Sets a maximum on the data that the Gemini API can use in a response. This is to manage API costs.
    - TEMPERATURE=0.7
        - Controls the randomness of the AI model output responses. 0.7 is a good number for a general chat bot.
    - DEBUG_MODE=0
        - Set to 1 if you want the script to output debugging information. Typically this should remain at 0.
    - SYSTEM_PROMPT=You are TwinMind, an AI demonstration exhibit in Second Life. Your responses should be brief (75-100 words at most) as they'll appear in public chat. Be helpful, and friendly. Your responses will be visible to everyone in the area, so keep them appropriate for all audiences, G-rated only.
        - Instructions to be given to the AI API. This governs how the bot behaves.
    - BOT_NAME=TwinMind
        - The name of the bot that will be displayed in chat messages. This name is automatically inserted into the SYSTEM_PROMPT when the config is loaded.
    - API_ENDPOINT=https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent
        - The API endpoint URL for Google's Gemini generateContent. Typically this should not be changed unless using a proxy or alternative endpoint.
    - LISTENING_CHANNEL=0
        - The chat channel the bot listens on. 0 is public chat. Change this if you want the bot to listen on a specific channel.
    - MAX_HISTORY_SIZE=10
        - Maximum number of messages to store in conversation history (includes both user messages and bot responses). Default of 10 stores 5 complete interactions.
    - HISTORY_TIMEOUT=1200.0
        - Time in seconds before conversation history expires. Default is 1200 seconds (20 minutes).
4. Create a new script in the inventory of the object and copy the contents of the twinmind.lsl file in this repository to the script contents.

**Instructions for Using the Chat Bot**
---
1. Stand within local chat distance of the chat bot object.
2. Type the Trigger Prefix ("*twin*" in the above example) followed by your request:
    - *twin What is Second life?*
3. The bot will respond with the AI model output, example:
    - **You:** *twin What is Second Life?*
    - **Bot Response:** *TwinMind: Second Life is an online virtual world launched in 2003 where users, called avatars, can explore, create, and socialize. You can build your own spaces, interact with others, attend events, and even create and sell virtual goods. It's a platform for creativity and community, allowing people from around the world to connect and experience a variety of activities in a 3D environment. Enjoy your adventures!*
4. The owner of the object can touch it to toggle the bot on/off.
5. The bot now maintains conversation history of the last 5 interactions (both user questions and bot responses), allowing for context-aware conversations.
6. Conversation history automatically expires after 20 minutes of inactivity.

**For Help**
---
Contact [Brian Aviator](https://my.secondlife.com/brian.aviator) by IM in world.
