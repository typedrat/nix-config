{
  resource = {
    authentik_user."ldap-search" = {
      username = "ldap-search";
      password = "\${ data.sops_file.authentik.data[\"ldap.password\"] }";
      type = "service_account";
    };

    authentik_rbac_role."ldap-search" = {
      name = "ldap-search";
    };

    authentik_group."ldap-search" = {
      name = "ldap-search";
      users = ["\${ authentik_user.ldap-search.id }"];
      roles = ["\${ authentik_rbac_role.ldap-search.id }"];
    };

    authentik_rbac_permission_role."ldap-search-directory" = {
      role = "\${ authentik_rbac_role.ldap-search.id }";
      permission = "authentik_providers_ldap.search_full_directory";
    };
  };
}
