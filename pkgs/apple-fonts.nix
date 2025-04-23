{
  inputs,
  stdenv,
  symlinkJoin,
}:
symlinkJoin {
  name = "apple-fonts";

  paths = with inputs.apple-fonts.packages.${stdenv.hostPlatform.system}; [
    sf-pro
    sf-compact
    sf-arabic
    sf-armenian
    sf-georgian
    sf-hebrew
    sf-mono
    ny
  ];
}
