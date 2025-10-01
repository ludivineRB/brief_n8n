// index.js
require('dotenv').config();
const { Client, GatewayIntentBits, Partials, Events } = require('discord.js');
const axios = require('axios');

const TOKEN = process.env.DISCORD_TOKEN;
const BOT_ID = process.env.BOT_ID;             // e.g. "123456789012345678"
const N8N_WEBHOOK = process.env.N8N_WEBHOOK;   // e.g. "https://.../webhook/discord-trigger"

if (!TOKEN || !BOT_ID || !N8N_WEBHOOK) {
  console.error('Missing env vars. Set DISCORD_TOKEN, BOT_ID, N8N_WEBHOOK in .env');
  process.exit(1);
}

// Create client
const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,                 // guild info
    GatewayIntentBits.GuildMessages,          // messageCreate in guilds
    GatewayIntentBits.MessageContent          // read message content (must be enabled on portal)
  ],
  partials: [Partials.Channel]
});

client.once(Events.ClientReady, (c) => {
  console.log(`✅ Logged in as ${c.user.tag} (id: ${c.user.id})`);
});

client.on(Events.MessageCreate, async (msg) => {
  try {
    // Ignore DMs and bots
    if (!msg.guild || msg.author.bot) return;

    // Check if the bot is mentioned
    // Safe check via mentions collection:
    const isMentioned = msg.mentions.users.has(BOT_ID);

    // (Optional extra: also catch raw mention text)
    // const rawMention = [`<@${BOT_ID}>`, `<@!${BOT_ID}>`].some(t => msg.content.includes(t));
    // const mentioned = isMentioned || rawMention;
    console.log("Debug : " + isMentioned)
    if (!isMentioned) return;

    // Build payload for n8n (raw-ish but compact)
    const payload = {
      content: msg.content,
      author: {
        id: msg.author.id,
        username: msg.author.username,
        discriminator: msg.author.discriminator,
        global_name: msg.author.globalName ?? null
      },
      channel_id: msg.channel.id,
      guild_id: msg.guild.id,
      message_id: msg.id,
      // Include mentions for downstream logic if you want
      mentions: msg.mentions.users.map(u => ({ id: u.id, username: u.username })),
      // Attachments (urls)
      attachments: msg.attachments.map(a => ({ id: a.id, name: a.name, url: a.url })),
      // Basic timestamp
      timestamp: msg.createdAt.toISOString()
    };

    // POST to n8n
    await axios.post(N8N_WEBHOOK, payload, {
      timeout: 10000,
      headers: { 'Content-Type': 'application/json' }
    });

    // (Optional) console log
    console.log(`➡️  Forwarded mention from @${msg.author.username} in #${msg.channel.id}`);
  } catch (err) {
    // Be graceful with Discord/HTTP errors
    console.error('Error handling message:', err?.response?.data || err.message || err);
  }
});

client.login(TOKEN);
