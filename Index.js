import {
  ChatInputCommandInteraction,
  Client,
  EmbedBuilder,
  Events,
  GatewayIntentBits,
  GuildMember,
  PermissionFlagsBits,
  PermissionsBitField,
  REST,
  Routes,
  SlashCommandBuilder,
} from "discord.js";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { logger } from "./lib/logger";

type WelcomeConfig = {
  channelId: string;
  message: string;
};

type BotConfig = Record<string, WelcomeConfig>;

const configPath = path.resolve(
  process.env["DISCORD_CONFIG_PATH"] ??
    "artifacts/api-server/data/discord-config.json",
);

const commands = [
  new SlashCommandBuilder()
    .setName("ping")
    .setDescription("Check whether the bot is online"),
  new SlashCommandBuilder()
    .setName("roblox")
    .setDescription("Show the latest Roblox client version")
    .addSubcommand((subcommand) =>
      subcommand
        .setName("updates")
        .setDescription("Check the latest Roblox update")
        .addStringOption((option) =>
          option
            .setName("platform")
            .setDescription("Choose the Roblox platform")
            .addChoices(
              { name: "Android", value: "android" },
              { name: "iOS", value: "ios" },
            )
            .setRequired(true),
        ),
    ),
  new SlashCommandBuilder()
    .setName("askai")
    .setDescription("Ask the AI a question")
    .addStringOption((option) =>
      option
        .setName("question")
        .setDescription("Your question")
        .setMaxLength(1500)
        .setRequired(true),
    ),
  new SlashCommandBuilder()
    .setName("searchyt")
    .setDescription("Search YouTube")
    .addStringOption((option) =>
      option
        .setName("search")
        .setDescription("What to search for on YouTube")
        .setMaxLength(200)
        .setRequired(true),
    ),
  new SlashCommandBuilder()
    .setName("help")
    .setDescription("Show the bot command list"),
  new SlashCommandBuilder()
    .setName("serverinfo")
    .setDescription("Show information about this server"),
  new SlashCommandBuilder()
    .setName("userinfo")
    .setDescription("Show information about a server member")
    .addUserOption((option) =>
      option
        .setName("user")
        .setDescription("The member to inspect")
        .setRequired(false),
    ),
  new SlashCommandBuilder()
    .setName("ban")
    .setDescription("Ban a member from this server")
    .setDefaultMemberPermissions(PermissionFlagsBits.BanMembers)
    .addUserOption((option) =>
      option
        .setName("user")
        .setDescription("The member to ban")
        .setRequired(true),
    )
    .addStringOption((option) =>
      option
        .setName("reason")
        .setDescription("Why the member is being banned")
        .setMaxLength(500)
        .setRequired(false),
    ),
  new SlashCommandBuilder()
    .setName("mute")
    .setDescription("Timeout a member temporarily")
    .setDefaultMemberPermissions(PermissionFlagsBits.ModerateMembers)
    .addUserOption((option) =>
      option
        .setName("user")
        .setDescription("The member to mute")
        .setRequired(true),
    )
    .addIntegerOption((option) =>
      option
        .setName("minutes")
        .setDescription("Mute duration in minutes, from 1 to 40320")
        .setMinValue(1)
        .setMaxValue(40320)
        .setRequired(false),
    )
    .addStringOption((option) =>
      option
        .setName("reason")
        .setDescription("Why the member is being muted")
        .setMaxLength(500)
        .setRequired(false),
    ),
  new SlashCommandBuilder()
    .setName("kick")
    .setDescription("Kick a member from this server")
    .setDefaultMemberPermissions(PermissionFlagsBits.KickMembers)
    .addUserOption((option) =>
      option
        .setName("user")
        .setDescription("The member to kick")
        .setRequired(true),
    )
    .addStringOption((option) =>
      option
        .setName("reason")
        .setDescription("Why the member is being kicked")
        .setMaxLength(500)
        .setRequired(false),
    ),
  new SlashCommandBuilder()
    .setName("announce")
    .setDescription("Post a formatted announcement")
    .setDefaultMemberPermissions(PermissionFlagsBits.ManageMessages)
    .addChannelOption((option) =>
      option
        .setName("channel")
        .setDescription("Where to post the announcement")
        .setRequired(true),
    )
    .addStringOption((option) =>
      option
        .setName("message")
        .setDescription("The announcement text")
        .setMaxLength(2000)
        .setRequired(true),
    ),
  new SlashCommandBuilder()
    .setName("message")
    .setDescription("Send a plain message to a text channel")
    .setDefaultMemberPermissions(PermissionFlagsBits.ManageMessages)
    .addChannelOption((option) =>
      option
        .setName("channel")
        .setDescription("Where to send the message")
        .setRequired(true),
    )
    .addStringOption((option) =>
      option
        .setName("text")
        .setDescription("The message text")
        .setMaxLength(2000)
        .setRequired(true),
    ),
  new SlashCommandBuilder()
    .setName("welcome")
    .setDescription("Configure welcome messages for this server")
    .setDefaultMemberPermissions(PermissionFlagsBits.ManageGuild)
    .addSubcommand((subcommand) =>
      subcommand
        .setName("set")
        .setDescription("Turn on welcome messages in a channel")
        .addChannelOption((option) =>
          option
            .setName("channel")
            .setDescription("The welcome channel")
            .setRequired(true),
        )
        .addStringOption((option) =>
          option
            .setName("message")
            .setDescription("Use {user} and {server} as placeholders")
            .setMaxLength(1000)
            .setRequired(false),
        ),
    )
    .addSubcommand((subcommand) =>
      subcommand
        .setName("show")
        .setDescription("Show the current welcome message settings"),
    )
    .addSubcommand((subcommand) =>
      subcommand
        .setName("off")
        .setDescription("Turn off welcome messages"),
    ),
  new SlashCommandBuilder()
    .setName("clear")
    .setDescription("Delete recent messages in the current channel")
    .setDefaultMemberPermissions(PermissionFlagsBits.ManageMessages)
    .addIntegerOption((option) =>
      option
        .setName("amount")
        .setDescription("Number of messages to delete, from 1 to 100")
        .setMinValue(1)
        .setMaxValue(100)
        .setRequired(true),
    ),
].map((command) => command.toJSON());

let config: BotConfig = {};

async function loadConfig(): Promise<void> {
  try {
    config = JSON.parse(await readFile(configPath, "utf8")) as BotConfig;
  } catch (error) {
    const code = error instanceof Error && "code" in error ? error.code : "";
    if (code !== "ENOENT") {
      logger.warn({ err: error }, "Could not read Discord bot config; using defaults");
    }
  }
}

async function saveConfig(): Promise<void> {
  await mkdir(path.dirname(configPath), { recursive: true });
  await writeFile(configPath, `${JSON.stringify(config, null, 2)}\n`, "utf8");
}

function reply(
  interaction: ChatInputCommandInteraction,
  content: string,
): Promise<unknown> {
  return interaction.reply({
    content,
    ephemeral: true,
    allowedMentions: { parse: [] },
  });
}

function isGuildInteraction(
  interaction: ChatInputCommandInteraction,
): boolean {
  return Boolean(interaction.guild && interaction.member);
}

function hasPermission(
  interaction: ChatInputCommandInteraction,
  permission: bigint,
): boolean {
  if (!interaction.guild || !interaction.member) return false;
  if (interaction.guild.ownerId === interaction.user.id) return true;
  const member = interaction.member;
  if (!("permissions" in member)) return false;
  const permissions = member.permissions;
  const permissionsBitField =
    typeof permissions === "string"
      ? new PermissionsBitField(BigInt(permissions))
      : new PermissionsBitField(permissions);
  return permissionsBitField.has(permission);
}

async function getTargetMember(
  interaction: ChatInputCommandInteraction,
): Promise<GuildMember | null> {
  const user = interaction.options.getUser("user", true);
  if (!interaction.guild) return null;
  try {
    return await interaction.guild.members.fetch(user.id);
  } catch {
    return null;
  }
}

function canModerateTarget(
  interaction: ChatInputCommandInteraction,
  target: GuildMember,
): string | null {
  if (!interaction.guild) return "This command can only be used in a server.";
  if (target.id === interaction.user.id) {
    return "You cannot moderate yourself.";
  }
  if (target.id === interaction.client.user?.id) {
    return "I cannot moderate myself.";
  }
  const executor = interaction.member;
  if (executor instanceof GuildMember) {
    if (
      interaction.guild.ownerId !== interaction.user.id &&
      executor.roles.highest.comparePositionTo(target.roles.highest) <= 0
    ) {
      return "You can only moderate members below your highest role.";
    }
  }
  return null;
}

async function getRobloxVersion(platform: "android" | "ios"): Promise<string> {
  const appVersion = platform === "android" ? "AppVersionAndroid" : "AppVersioniOS";
  const endpoint = `https://clientsettings.roblox.com/v1/mobile-client-version?appVersion=${appVersion}`;
  const response = await fetch(endpoint, {
    headers: { "User-Agent": "OPEX-HUB-Discord-Bot/1.0" },
  });
  if (!response.ok) {
    throw new Error(`Roblox version request failed with ${response.status}`);
  }
  const data = (await response.json()) as { activeVersion?: unknown };
  if (
    typeof data.activeVersion !== "string" ||
    data.activeVersion.length === 0
  ) {
    throw new Error("Roblox returned no client version");
  }
  return data.activeVersion;
}

async function askOpenAi(question: string): Promise<string> {
  const apiKey = process.env["OPENAI_API_KEY"]?.trim();
  if (!apiKey) {
    return "The AI command is not configured yet. Add the OPENAI_API_KEY secret first.";
  }

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-5.4-mini",
      max_completion_tokens: 700,
      messages: [
        {
          role: "system",
          content:
            "Answer clearly and helpfully. Keep the response under 1,800 characters.",
        },
        { role: "user", content: question },
      ],
    }),
  });

  if (!response.ok) {
    throw new Error(`OpenAI request failed with ${response.status}`);
  }
  const data = (await response.json()) as {
    choices?: Array<{ message?: { content?: unknown } }>;
  };
  const answer = data.choices?.[0]?.message?.content;
  if (typeof answer !== "string" || answer.length === 0) {
    throw new Error("OpenAI returned no answer");
  }
  return answer.length > 1_800 ? `${answer.slice(0, 1_797)}...` : answer;
}

async function handleInteraction(
  interaction: ChatInputCommandInteraction,
): Promise<void> {
  if (!isGuildInteraction(interaction) && interaction.commandName !== "ping") {
    await reply(interaction, "This command must be used inside a server.");
    return;
  }

  if (interaction.commandName === "ping") {
    await interaction.reply(`Pong 🏓  ${interaction.client.ws.ping}ms`);
    return;
  }

  if (interaction.commandName === "roblox") {
    if (interaction.options.getSubcommand() !== "updates") return;
    const platform = interaction.options.getString("platform", true) as
      | "android"
      | "ios";
    await interaction.deferReply({ ephemeral: true });
    try {
      const version = await getRobloxVersion(platform);
      await interaction.editReply({
        content: [
          `**Roblox ${platform === "android" ? "Android" : "iOS"} update**`,
          `Latest client version: \`${version}\``,
          "Checked live from Roblox just now.",
        ].join("\n"),
        allowedMentions: { parse: [] },
      });
    } catch {
      await interaction.editReply(
        "I could not check the Roblox update service right now. Please try again shortly.",
      );
    }
    return;
  }

  if (interaction.commandName === "askai") {
    const question = interaction.options.getString("question", true).trim();
    await interaction.deferReply({ ephemeral: true });
    try {
      const answer = await askOpenAi(question);
      await interaction.editReply({
        content: answer,
        allowedMentions: { parse: [] },
      });
    } catch {
      await interaction.editReply(
        "The AI service could not answer right now. Please try again shortly.",
      );
    }
    return;
  }

  if (interaction.commandName === "searchyt") {
    const search = interaction.options.getString("search", true).trim();
    const searchUrl = `https://www.youtube.com/results?search_query=${encodeURIComponent(search)}`;
    await reply(
      interaction,
      `YouTube results for **${search}**:\n${searchUrl}`,
    );
    return;
  }

  if (interaction.commandName === "help") {
    await reply(
      interaction,
      [
        "**Available commands**",
        "`/ping` — Check latency",
        "`/roblox updates platform:<Android|iOS>` — Check the latest Roblox client version",
        "`/askai question:<question>` — Ask the AI",
        "`/searchyt search:<query>` — Search YouTube",
        "`/serverinfo` — Show server details",
        "`/userinfo` — Show member details",
        "`/ban`, `/mute`, `/kick` — Moderation",
        "`/announce`, `/message` — Send staff messages",
        "`/welcome set|show|off` — Welcome configuration",
        "`/clear` — Delete recent messages",
        "Sensitive-attribute guessing commands are not supported.",
      ].join("\n"),
    );
    return;
  }

  if (interaction.commandName === "serverinfo") {
    const guild = interaction.guild;
    if (!guild) return;
    await reply(
      interaction,
      [
        `**${guild.name}**`,
        `Owner: <@${guild.ownerId}>`,
        `Members: ${guild.memberCount}`,
        `Channels: ${guild.channels.cache.size}`,
        `Created: <t:${Math.floor(guild.createdTimestamp / 1000)}:D>`,
      ].join("\n"),
    );
    return;
  }

  if (interaction.commandName === "userinfo") {
    const guild = interaction.guild;
    if (!guild) return;
    const selectedUser =
      interaction.options.getUser("user") ?? interaction.user;
    const member = await guild.members.fetch(selectedUser.id).catch(() => null);
    await reply(
      interaction,
      [
        `**${selectedUser.tag}**`,
        `User ID: \`${selectedUser.id}\``,
        `Joined: ${
          member?.joinedTimestamp
            ? `<t:${Math.floor(member.joinedTimestamp / 1000)}:D>`
            : "Not available"
        }`,
        `Account created: <t:${Math.floor(selectedUser.createdTimestamp / 1000)}:D>`,
      ].join("\n"),
    );
    return;
  }

  if (interaction.commandName === "ban") {
    if (!hasPermission(interaction, PermissionFlagsBits.BanMembers)) {
      await reply(interaction, "You need the Ban Members permission.");
      return;
    }
    const target = await getTargetMember(interaction);
    if (!target) {
      await reply(interaction, "That member is not in this server.");
      return;
    }
    const hierarchyError = canModerateTarget(interaction, target);
    if (hierarchyError) {
      await reply(interaction, hierarchyError);
      return;
    }
    if (!target.bannable) {
      await reply(interaction, "I cannot ban that member. Check my role position and permissions.");
      return;
    }
    const reason = interaction.options.getString("reason") ?? "No reason provided";
    await target.ban({ deleteMessageSeconds: 0, reason });
    await reply(interaction, `Banned **${target.user.tag}**. Reason: ${reason}`);
    return;
  }

  if (interaction.commandName === "kick") {
    if (!hasPermission(interaction, PermissionFlagsBits.KickMembers)) {
      await reply(interaction, "You need the Kick Members permission.");
      return;
    }
    const target = await getTargetMember(interaction);
    if (!target) {
      await reply(interaction, "That member is not in this server.");
      return;
    }
    const hierarchyError = canModerateTarget(interaction, target);
    if (hierarchyError) {
      await reply(interaction, hierarchyError);
      return;
    }
    if (!target.kickable) {
      await reply(interaction, "I cannot kick that member. Check my role position and permissions.");
      return;
    }
    const reason = interaction.options.getString("reason") ?? "No reason provided";
    await target.kick(reason);
    await reply(interaction, `Kicked **${target.user.tag}**. Reason: ${reason}`);
    return;
  }

  if (interaction.commandName === "mute") {
    if (!hasPermission(interaction, PermissionFlagsBits.ModerateMembers)) {
      await reply(interaction, "You need the Moderate Members permission.");
      return;
    }
    const target = await getTargetMember(interaction);
    if (!target) {
      await reply(interaction, "That member is not in this server.");
      return;
    }
    const hierarchyError = canModerateTarget(interaction, target);
    if (hierarchyError) {
      await reply(interaction, hierarchyError);
      return;
    }
    if (!target.moderatable) {
      await reply(interaction, "I cannot mute that member. Check my role position and permissions.");
      return;
    }
    const minutes = interaction.options.getInteger("minutes") ?? 10;
    const reason = interaction.options.getString("reason") ?? "No reason provided";
    await target.timeout(minutes * 60 * 1000, reason);
    await reply(interaction, `Muted **${target.user.tag}** for ${minutes} minute(s). Reason: ${reason}`);
    return;
  }

  if (interaction.commandName === "announce" || interaction.commandName === "message") {
    if (!hasPermission(interaction, PermissionFlagsBits.ManageMessages)) {
      await reply(interaction, "You need the Manage Messages permission.");
      return;
    }
    const channel = interaction.options.getChannel("channel", true);
    if (
      !("isTextBased" in channel) ||
      !channel.isTextBased() ||
      !("send" in channel)
    ) {
      await reply(interaction, "Choose a text channel.");
      return;
    }
    const content =
      interaction.options.getString(
        interaction.commandName === "announce" ? "message" : "text",
        true,
      );
    if (interaction.commandName === "announce") {
      await channel.send({
        embeds: [
          new EmbedBuilder()
            .setColor(0x5865f2)
            .setTitle("Announcement")
            .setDescription(content)
            .setFooter({ text: `Posted by ${interaction.user.tag}` }),
        ],
      });
    } else {
      await channel.send({ content });
    }
    await reply(interaction, `Message sent to <#${channel.id}>.`);
    return;
  }

  if (interaction.commandName === "welcome") {
    if (!hasPermission(interaction, PermissionFlagsBits.ManageGuild)) {
      await reply(interaction, "You need the Manage Server permission.");
      return;
    }
    const guild = interaction.guild;
    if (!guild) return;
    const subcommand = interaction.options.getSubcommand();
    if (subcommand === "set") {
      const channel = interaction.options.getChannel("channel", true);
      if (
        !("isTextBased" in channel) ||
        !channel.isTextBased() ||
        !("send" in channel)
      ) {
        await reply(interaction, "Choose a text channel.");
        return;
      }
      config[guild.id] = {
        channelId: channel.id,
        message:
          interaction.options.getString("message") ??
          "Welcome {user} to **{server}**!",
      };
      await saveConfig();
      await reply(
        interaction,
        `Welcome messages are enabled in <#${channel.id}>.\nTemplate: ${config[guild.id].message}`,
      );
      return;
    }
    if (subcommand === "off") {
      delete config[guild.id];
      await saveConfig();
      await reply(interaction, "Welcome messages are turned off.");
      return;
    }
    const current = config[guild.id];
    await reply(
      interaction,
      current
        ? `Welcome messages: <#${current.channelId}>\nTemplate: ${current.message}`
        : "Welcome messages are currently off.",
    );
    return;
  }

  if (interaction.commandName === "clear") {
    if (!hasPermission(interaction, PermissionFlagsBits.ManageMessages)) {
      await reply(interaction, "You need the Manage Messages permission.");
      return;
    }
    if (!interaction.channel || !("bulkDelete" in interaction.channel)) {
      await reply(interaction, "Use this command in a server text channel.");
      return;
    }
    const amount = interaction.options.getInteger("amount", true);
    const deleted = await interaction.channel.bulkDelete(amount, true);
    await reply(interaction, `Deleted ${deleted.size} message(s).`);
  }
}

export async function startDiscordBot(): Promise<void> {
  if (process.env["NODE_ENV"] === "development") {
    logger.info("Discord bot is disabled in the development workflow; use the production deployment for the Gateway bot");
    return;
  }

  const token = process.env["DISCORD_TOKEN"]?.trim();
  if (!token) {
    logger.warn("DISCORD_TOKEN is not set; Discord bot is disabled");
    return;
  }

  await loadConfig();
  const client = new Client({
    intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMembers],
  });

  client.once(Events.ClientReady, async (readyClient) => {
    try {
      const rest = new REST({ version: "10" }).setToken(token);
      await rest.put(Routes.applicationCommands(readyClient.user.id), {
        body: commands,
      });
      logger.info(
        { user: readyClient.user.tag, commandCount: commands.length },
        "Discord bot is ready",
      );
    } catch (error) {
      logger.error({ err: error }, "Could not register Discord slash commands");
    }
  });

  client.on(Events.InteractionCreate, (interaction) => {
    if (!interaction.isChatInputCommand()) return;
    handleInteraction(interaction).catch((error) => {
      logger.error(
        { err: error, command: interaction.commandName },
        "Discord command failed",
      );
      const response = {
        content: "That command could not be completed. Check the bot permissions and try again.",
        ephemeral: true,
      };
      if (interaction.replied || interaction.deferred) {
        void interaction.followUp(response);
      } else {
        void interaction.reply(response);
      }
    });
  });

  client.on(Events.Error, (error) => {
    logger.error({ err: error }, "Discord client error");
  });

  client.on(Events.GuildMemberAdd, async (member) => {
    const welcome = config[member.guild.id];
    if (!welcome) return;
    const channel = member.guild.channels.cache.get(welcome.channelId);
    if (!channel?.isTextBased() || !("send" in channel)) return;
    const content = welcome.message
      .replaceAll("{user}", `<@${member.id}>`)
      .replaceAll("{server}", member.guild.name);
    try {
      await channel.send({
        content,
        allowedMentions: { users: [member.id] },
      });
    } catch (error) {
      logger.warn(
        { err: error, guildId: member.guild.id },
        "Could not send welcome message",
      );
    }
  });

  try {
    await client.login(token);
  } catch (error) {
    logger.error({ err: error }, "Discord bot could not log in");
    process.exit(1);
  }
}
