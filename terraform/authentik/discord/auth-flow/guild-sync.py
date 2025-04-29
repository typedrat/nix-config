from authentik.core.models import Group # type: ignore
GUILD_API_URL = f"https://discord.com/api/users/@me/guilds/{GUILD_ID}/member"

# Ensure flow is only run during OAuth logins via Discord
if context["source"].provider_type != "discord":
    return True # type: ignore

# Get the user-source connection object from the context, and get the access token
connection = context.get("goauthentik.io/sources/connection")
if not connection:
    return False # type: ignore
access_token = connection.access_token

guild_member_request = requests.get(
    GUILD_API_URL,
    headers={
        "Authorization": f"Bearer {access_token}"
    },
)
guild_member_info = guild_member_request.json()

# Ensure we are not being ratelimited
if guild_member_request.status_code == 429:
    ak_message(f"Discord is throttling this connection. Retry in {int(guild_member_info['retry_after'])}s")
    return False # type: ignore

# Ensure user is a member of the guild
if "code" in guild_member_info:
    if guild_member_info["code"] == 10004:
        ak_message(f"User is not a member of the guild '{GUILD_NAME}'")
    else:
        ak_create_event("discord_error", source=context["source"], code=guild_member_info["code"])
        ak_message("Discord API error, try again later.")
    return False # type: ignore

# Get all discord_groups
discord_groups = Group.objects.filter(attributes__discord_role_id__isnull=False)

# Split user groups into discord groups and non discord groups
user_groups_non_discord = request.user.ak_groups.exclude(pk__in=discord_groups.values_list("pk", flat=True))
user_groups_discord = list(request.user.ak_groups.filter(pk__in=discord_groups.values_list("pk", flat=True)))

# Filter matching roles based on guild_member_info['roles']
user_groups_discord_updated = discord_groups.filter(attributes__discord_role_id__in=guild_member_info["roles"])

# Filter out groups where the user has an excluded role
for group in user_groups_discord_updated:
    excluded_role_id = group.attributes.get('discord_role_id_exclude')
    if excluded_role_id and excluded_role_id in guild_member_info["roles"]:
        user_groups_discord_updated = user_groups_discord_updated.exclude(pk=group.pk)

# Combine user_groups_non_discord and matching_roles
user_groups_updated = user_groups_non_discord.union(user_groups_discord_updated)

# Update user's groups
request.user.ak_groups.set(user_groups_updated)

# Create event with roles changed
ak_create_event(
    "discord_role_sync",
    user_discord_roles_before=", ".join(str(group) for group in user_groups_discord),
    user_discord_roles_after=", ".join(str(group) for group in user_groups_discord_updated),
)

return True # type: ignore
