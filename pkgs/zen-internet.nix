{
  buildFirefoxXpiAddon,
  lib,
}:
buildFirefoxXpiAddon rec {
  pname = "zen-internet";
  version = "1.7.2";
  addonId = "{91aa3897-2634-4a8a-9092-279db23a7689}";
  url = "https://addons.mozilla.org/firefox/downloads/file/4474349/zen_internet-${version}.xpi";
  sha256 = "sha256-U9uL0JAPqWDjmvrCstOE4lqW9LVgsgbSmDdklwCZLzg=";
  meta = with lib; {
    homepage = "https://github.com/sameerasw/my-internet";
    description = "Custom CSS to make the web transparent, beautiful and zen.";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
