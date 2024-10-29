<?php
// Configurazione di sicurezza phpMyAdmin
$cfg['LoginCookieValidity'] = 1800; // 30 minuti
$cfg['LoginCookieStore'] = 0; // No remember me
$cfg['AuthLog'] = 'syslog';
$cfg['AllowArbitraryServer'] = false;
$cfg['SuhosinDisableWarning'] = true;
$cfg['LoginCookieRecall'] = false;
$cfg['RememberSorting'] = true;
$cfg['DefaultConnectionCollation'] = 'utf8mb4_unicode_ci';
$cfg['MaxRows'] = 50;
$cfg['OrderByKey'] = true;
$cfg['TableNavigationLinksMode'] = 'icons';
$cfg['PropertiesNumColumns'] = 1;
$cfg['MaxNavigationItems'] = 100;
$cfg['NavigationTreeEnableGrouping'] = true;
$cfg['ShowPhpInfo'] = false;
$cfg['ShowChgPassword'] = true;
$cfg['ShowAll'] = false;
$cfg['AllowUserDropDatabase'] = false;
$cfg['EnableAdvancedFeatures'] = false;
// Limita accesso solo a determinati IP (opzionale)
// $cfg['TrustedProxies'] = ['IP-DEL-TUO-PROXY'];
