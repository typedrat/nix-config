{
  resource.authentik_brand."thisratisgay" = {
    domain = "thisratis.gay";
    branding_title = "This Rat is Gay";
    branding_logo = "/static/dist/assets/icons/icon_left_brand.svg";
    branding_favicon = "/static/dist/assets/icons/icon.png";
    flow_authentication = "\${ data.authentik_flow.default-authentication-flow.id }";
    flow_invalidation = "\${ data.authentik_flow.default-invalidation-flow.id }";
    flow_user_settings = "\${ authentik_flow.user-settings.uuid }";
  };
}
