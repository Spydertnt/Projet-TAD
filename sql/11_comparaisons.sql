-- Générer un jeu de test conséquent pour que les différences de performance soient significatives
-- (50 000 Cergy + 30 000 Pau -> 80 000 equipements)
EXEC SP_GENERER_JEU_DE_TEST(50000, 30000);

-- Vider la table de résultats de benchmark pour ne pas fausser les résultats avec les tests précédents
DELETE FROM BENCHMARK_RESULTS;

-- Tester la base optimisée avec les indexs
EXEC SP_RUN_BENCHMARK_ASSETS('AVEC_INDEX');

---------------- Enlever les indexs d'optimisation -----------------

-- INDEX B-TREE SUR CLES ETRANGERES
ALTER INDEX idx_sites_parent INVISIBLE;
ALTER INDEX idx_sites_code INVISIBLE;
ALTER INDEX idx_locations_parent INVISIBLE;
ALTER INDEX idx_users_site INVISIBLE;
ALTER INDEX idx_users_location INVISIBLE;
ALTER INDEX idx_users_supervisor INVISIBLE;
ALTER INDEX idx_pu_profile INVISIBLE;
ALTER INDEX idx_pu_site INVISIBLE;
ALTER INDEX idx_groups_parent INVISIBLE;
ALTER INDEX idx_gu_group INVISIBLE;
ALTER INDEX idx_assets_site INVISIBLE;
ALTER INDEX idx_assets_owner INVISIBLE;
ALTER INDEX idx_assets_technician INVISIBLE;
ALTER INDEX idx_assets_location INVISIBLE;
ALTER INDEX idx_assets_manuf INVISIBLE;
ALTER INDEX idx_assets_state INVISIBLE;
ALTER INDEX idx_ticket_site INVISIBLE;
ALTER INDEX idx_ticket_asset INVISIBLE;
ALTER INDEX idx_ticket_status INVISIBLE;
ALTER INDEX idx_ticket_requester INVISIBLE;
ALTER INDEX idx_ticket_assigned_group INVISIBLE;
ALTER INDEX idx_ticket_category INVISIBLE;
ALTER INDEX idx_ticket_created_at INVISIBLE;
ALTER INDEX idx_tu_ticket INVISIBLE;
ALTER INDEX idx_tu_user INVISIBLE;
ALTER INDEX idx_tu_assigned_by INVISIBLE;
ALTER INDEX idx_tf_ticket INVISIBLE;
ALTER INDEX idx_tf_user INVISIBLE;
ALTER INDEX idx_np_site INVISIBLE;
ALTER INDEX idx_np_asset INVISIBLE;
ALTER INDEX idx_ipn_vlan_tag INVISIBLE;
ALTER INDEX idx_ip_site INVISIBLE;
ALTER INDEX idx_ip_network INVISIBLE;

-- INDEX COMPOSITES POUR LES REQUETES METIER
ALTER INDEX idx_assets_site_type INVISIBLE;
ALTER INDEX idx_assets_site_state INVISIBLE;
ALTER INDEX idx_assets_site_owner INVISIBLE;
ALTER INDEX idx_assets_site_location INVISIBLE;
ALTER INDEX idx_ticket_site_status_priority INVISIBLE;
ALTER INDEX idx_ticket_asset_status INVISIBLE;
ALTER INDEX idx_ticket_group_status INVISIBLE;
ALTER INDEX idx_pu_site_user INVISIBLE;
ALTER INDEX idx_network_site_address INVISIBLE;
ALTER INDEX idx_ip_network_address INVISIBLE;

-- INDEX FONCTIONNELS
ALTER INDEX idx_assets_name_upper INVISIBLE;
ALTER INDEX idx_assets_serial_upper INVISIBLE;
ALTER INDEX idx_users_login_upper INVISIBLE;
ALTER INDEX idx_users_email_upper INVISIBLE;

-- INDEX BITMAP POUR COLONNES A FAIBLE CARDINALITE
ALTER INDEX bmp_assets_type INVISIBLE;
ALTER INDEX bmp_users_active INVISIBLE;
ALTER INDEX bmp_tickets_priority INVISIBLE;
ALTER INDEX bmp_np_type INVISIBLE;

-- INDEX TABLES SYSTEME
ALTER INDEX idx_audit_table INVISIBLE;
ALTER INDEX idx_audit_date INVISIBLE;
ALTER INDEX idx_audit_table_record INVISIBLE;
ALTER INDEX idx_archives_original INVISIBLE;
ALTER INDEX idx_archives_date INVISIBLE;

-- Vider la mémoire vive pour que Oracle ne triche pas en se souvenant des requêtes précédentes
ALTER SYSTEM FLUSH BUFFER_CACHE;
ALTER SYSTEM FLUSH SHARED_POOL;

-- Tester la base standard sans les indexs
EXEC SP_RUN_BENCHMARK_ASSETS('SANS_INDEX');

--Afficher le tableau de comparaison final
SELECT query_id, query_desc, scenario, execution_ms
FROM BENCHMARK_RESULTS
ORDER BY query_id, scenario;

---------------- Remettre les indexs pour les prochaines utilisations -----------------

-- INDEX B-TREE SUR CLES ETRANGERES
ALTER INDEX idx_sites_parent VISIBLE;
ALTER INDEX idx_sites_code VISIBLE;
ALTER INDEX idx_locations_parent VISIBLE;
ALTER INDEX idx_users_site VISIBLE;
ALTER INDEX idx_users_location VISIBLE;
ALTER INDEX idx_users_supervisor VISIBLE;
ALTER INDEX idx_pu_profile VISIBLE;
ALTER INDEX idx_pu_site VISIBLE;
ALTER INDEX idx_groups_parent VISIBLE;
ALTER INDEX idx_gu_group VISIBLE;
ALTER INDEX idx_assets_site VISIBLE;
ALTER INDEX idx_assets_owner VISIBLE;
ALTER INDEX idx_assets_technician VISIBLE;
ALTER INDEX idx_assets_location VISIBLE;
ALTER INDEX idx_assets_manuf VISIBLE;
ALTER INDEX idx_assets_state VISIBLE;
ALTER INDEX idx_ticket_site VISIBLE;
ALTER INDEX idx_ticket_asset VISIBLE;
ALTER INDEX idx_ticket_status VISIBLE;
ALTER INDEX idx_ticket_requester VISIBLE;
ALTER INDEX idx_ticket_assigned_group VISIBLE;
ALTER INDEX idx_ticket_category VISIBLE;
ALTER INDEX idx_ticket_created_at VISIBLE;
ALTER INDEX idx_tu_ticket VISIBLE;
ALTER INDEX idx_tu_user VISIBLE;
ALTER INDEX idx_tu_assigned_by VISIBLE;
ALTER INDEX idx_tf_ticket VISIBLE;
ALTER INDEX idx_tf_user VISIBLE;
ALTER INDEX idx_np_site VISIBLE;
ALTER INDEX idx_np_asset VISIBLE;
ALTER INDEX idx_ipn_vlan_tag VISIBLE;
ALTER INDEX idx_ip_site VISIBLE;
ALTER INDEX idx_ip_network VISIBLE;

-- INDEX COMPOSITES POUR LES REQUETES METIER
ALTER INDEX idx_assets_site_type VISIBLE;
ALTER INDEX idx_assets_site_state VISIBLE;
ALTER INDEX idx_assets_site_owner VISIBLE;
ALTER INDEX idx_assets_site_location VISIBLE;
ALTER INDEX idx_ticket_site_status_priority VISIBLE;
ALTER INDEX idx_ticket_asset_status VISIBLE;
ALTER INDEX idx_ticket_group_status VISIBLE;
ALTER INDEX idx_pu_site_user VISIBLE;
ALTER INDEX idx_network_site_address VISIBLE;
ALTER INDEX idx_ip_network_address VISIBLE;

-- INDEX FONCTIONNELS
ALTER INDEX idx_assets_name_upper VISIBLE;
ALTER INDEX idx_assets_serial_upper VISIBLE;
ALTER INDEX idx_users_login_upper VISIBLE;
ALTER INDEX idx_users_email_upper VISIBLE;

-- INDEX BITMAP POUR COLONNES A FAIBLE CARDINALITE
ALTER INDEX bmp_assets_type VISIBLE;
ALTER INDEX bmp_users_active VISIBLE;
ALTER INDEX bmp_tickets_priority VISIBLE;
ALTER INDEX bmp_np_type VISIBLE;

-- INDEX TABLES SYSTEME
ALTER INDEX idx_audit_table VISIBLE;
ALTER INDEX idx_audit_date VISIBLE;
ALTER INDEX idx_audit_table_record VISIBLE;
ALTER INDEX idx_archives_original VISIBLE;
ALTER INDEX idx_archives_date VISIBLE;