{
  boot.zfs.extraPools = ["zfspv-pool"];

  # zfspv-pool holds the raw-encrypted (syncoid `-w`) backups received from other
  # hosts. Those datasets keep their source keylocation=prompt but iserlohn never
  # has the key. With the default (true), zfs-import-zfspv-pool.service walks the
  # pool and blocks boot forever on systemd-ask-password (passwordTimeout=0) for a
  # key that will never arrive. iserlohn has no ZFS-native encrypted datasets that
  # need unlocking at boot (rpool is unlocked at the LUKS layer, zfspv-pool's root
  # is unencrypted), so never request ZFS credentials: the backups stay inert.
  boot.zfs.requestEncryptionCredentials = false;
}
