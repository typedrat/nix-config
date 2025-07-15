{
  authentik.applications.sillytavern = {
    name = "SillyTavern";
    group = "Communication";
    icon = "https://raw.githubusercontent.com/SillyTavern/SillyTavern/release/public/img/logo.png";
    description = "AI Chat Interface for roleplay and creative writing";
    accessGroups = ["discord-user"];

    proxy = {
      externalHost = "https://sillytavern.thisratis.gay";
      basicAuth = {
        enable = false;
      };
    };
  };
}
