{
  resource = {
    authentik_user."ldap-search" = {
      username = "ldap-search";
      password = "\${ data.sops_file.authentik.data[\"ldap.password\"] }";
      type = "service_account";
    };

    authentik_rbac_permission_user."ldap-search-users" = {
      user = "\${ authentik_user.ldap-search.id }";
      permission = "authentik_providers_ldap.search_full_directory";
    };
  };
}
