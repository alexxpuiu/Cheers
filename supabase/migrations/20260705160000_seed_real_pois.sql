-- ============================================================================
-- Cheers — real POI seed (Barcelona, Mapbox Search Box)
-- ----------------------------------------------------------------------------
-- Apply after `20260705150000_bucket_list_sync.sql`.
--
-- Replaces the `lib/data/mock_pois.dart` catalog. Pulled from the Mapbox
-- Search Box category endpoint across a Barcelona bbox and filtered for
-- quality (Latin names, no tour-operator noise, cross-category dedup).
-- Deterministic uuid5 ids over Mapbox's `mapbox_id` make the migration
-- idempotent — safe to re-run when the catalog needs a refresh.
--
-- Regenerate with `python3 scripts/seed_pois.py > <this file>`.
-- ============================================================================

insert into public.pois (id, name, category, lat, lng, address, avg_visit_minutes)
values
  ('2ba6c1c1-098f-5a3a-af0b-3470820e7e20', 'Barcelo Raval', 'accommodation', 41.37907, 2.169662, 'Rambla del Raval, 08001 Barcelona', 720),
  ('1f8a3dec-5fda-5e0b-b434-648b1e91f2ae', 'Casa Gràcia', 'accommodation', 41.397175, 2.159252, 'Pg. de Gràcia, 08008 Barcelona', 720),
  ('5f6d41c1-fed5-5922-9235-1e94df03d1c6', 'El Palace Hotel', 'accommodation', 41.391399, 2.171451, 'Gran Via de les Corts Catalanes, 08010 Barcelona', 720),
  ('b53090d1-1f5e-5df4-82d7-95de745d0622', 'Eurostars Grand Marina', 'accommodation', 41.37178294, 2.18083152, 'Moll de Barcelona, 08039 Barcelona', 720),
  ('502fe53c-9c91-5e17-8a90-400422761248', 'H10 Marina Barcelona Hotel', 'accommodation', 41.3931608, 2.1925962, 'Olympic Village Aviniguda del Bogatell 64 68, 08005 Barcelona', 720),
  ('6d1dd55c-b637-5ed1-a862-d6499062eee2', 'Hotel Arts Barcelona', 'accommodation', 41.3869266, 2.1962869, 'Carrer de la Marina 19-21, 08005 Barcelona', 720),
  ('ac011245-dd5a-5ce7-9c3c-e12c32592ae9', 'Hotel Barceló Sants', 'accommodation', 41.3789812, 2.13927359, 'Pl. dels Països Catalans, 08014 Barcelona', 720),
  ('2c8d4dac-05d7-5c57-b157-63f1799e25b9', 'Hotel Casa Fuster', 'accommodation', 41.397987, 2.158054, 'Pg. de Gràcia, 08008 Barcelona', 720),
  ('e00a064d-a60e-5290-b9d9-226244018d38', 'Hotel Catalonia Barcelona Plaza', 'accommodation', 41.37549701, 2.14843782, 'Pl. d''Espanya, 08014 Barcelona', 720),
  ('83a5ff20-90fd-5749-bb92-7ca4dbb78f11', 'Hotel Condes de Barcelona', 'accommodation', 41.393551, 2.1627, 'Pg. de Gràcia, 08008 Barcelona', 720),
  ('8b6044e8-2080-5080-8fb3-e352093c4690', 'Hotel Gargallo Rialto', 'accommodation', 41.38206559, 2.17640628, 'Carrer de Ferran, 08002 Barcelona', 720),
  ('b14c098c-06db-5113-b364-47ee87fcdb7b', 'Intercontinental Barcelona', 'accommodation', 41.3727, 2.154541, 'Av. de Rius i Taulet, 08004 Barcelona', 720),
  ('b45199f8-d4dc-550b-b0cb-745bc1791c70', 'Majestic Hotel and Spa', 'accommodation', 41.39345297, 2.16404155, 'Pg. de Gràcia, 08007 Barcelona', 720),
  ('3daf12a0-55a1-5b1a-adec-21284cc3d806', 'Mandarin Oriental Barcelona', 'accommodation', 41.39115097, 2.16653672, 'Pg. de Gràcia, 08007 Barcelona', 720),
  ('8b5f34c0-fd3d-5565-89f8-25c2ee849049', 'Meliá Barcelona Sky', 'accommodation', 41.406288, 2.200672, 'Carrer de Pere IV, 08005 Barcelona', 720),
  ('0cbe66cf-948f-54e3-8989-650381677db9', 'Novotel Barcelona City', 'accommodation', 41.40370677, 2.19129203, 'Avenida Diagonal, 08018 Barcelona', 720),
  ('168c49e4-6d56-554f-9fed-6bf53db09b01', 'Sercotel Rosellón', 'accommodation', 41.404743, 2.172772, 'Carrer del Rosselló, 08025 Barcelona', 720),
  ('24634b57-4f50-5359-a2c4-77a4872ea4f9', 'W Barcelona', 'accommodation', 41.3684393, 2.1899445, 'Plaça Rosa Del Vents 1, 08039 Barcelona', 720),
  ('752f9ef9-1d7c-52cb-abc6-8fbb1b68c298', '7 Portes', 'dining', 41.3822593, 2.1834171, 'Passeig d''Isabel II 14, 08003 Barcelona', 90),
  ('2b41fd08-2f06-56f3-8559-7fa34250b7bd', 'Antigua', 'dining', 41.397991, 2.149266, 'Carrer de Marià Cubí, 08006 Barcelona', 90),
  ('bc751902-59e2-5a8a-8526-7b1a60ba4530', 'Arab Halal Marrakech', 'dining', 41.3787, 2.143651, 'Carrer de Béjar, 08014 Barcelona', 90),
  ('5d71eb41-f11a-57c4-b68d-c46cdcc2d06d', 'Asado Bufet Lliure de Carns Argentines', 'dining', 41.401299, 2.169581, 'Carrer de Roger de Flor, 08025 Barcelona', 90),
  ('28f062e3-4290-5592-96fe-c31e1ba27531', 'Botafumeiro', 'dining', 41.400425, 2.154639, 'Carrer Gran de Gràcia, 08012 Barcelona', 90),
  ('a80cbebb-942e-52ee-ba69-fb5bc88ba7fe', 'Cañete', 'dining', 41.379169, 2.173103, 'Carrer de la Unió, 08001 Barcelona', 90),
  ('1223fc45-8ccc-5f1b-a09c-1dcd12d98e6d', 'Ciutat Comtal', 'dining', 41.38879263, 2.1669206, 'Rambla de Catalunya, 08007 Barcelona', 90),
  ('07a1be0a-8bb4-5fec-bbff-d483dae453db', 'Colom Restaurant', 'dining', 41.3798407, 2.1764997, 'Carrer dels Escudellers 33, 08002 Barcelona', 90),
  ('236f89aa-79f0-519c-810e-5e0add527d71', 'El Argentino', 'dining', 41.388638, 2.160207, 'Carrer d''Aragó, 08011 Barcelona', 90),
  ('c686ceea-b320-5f77-b0a5-b2c3e4b57a93', 'Jesús Restaurant', 'dining', 41.38186377, 2.17472794, 'Carrer dels Cecs de la Boqueria, 08002 Barcelona', 90),
  ('bcbd68ca-8e98-5913-8e57-3f31119a725e', 'La Fonda', 'dining', 41.379501, 2.176261, 'Carrer dels Escudellers, 08002 Barcelona', 90),
  ('155596f2-4e6a-5ab9-982b-25ae6d0ba173', 'Micu Maku', 'dining', 41.3868619, 2.1617423, 'Carrer d''Aribau 22, 08011 Barcelona', 90),
  ('4336c45f-a487-5779-b745-42b4108531f1', 'Mirablau', 'dining', 41.416031, 2.131925, 'Plaça del Doctor Andreu, 08035 Barcelona', 90),
  ('8a0cc312-2fe9-5d9a-b733-dfc92db89b22', 'Ocaña', 'dining', 41.379848, 2.175704, 'Pl. Reial, 08002 Barcelona', 90),
  ('a754ffb7-0b16-56e4-bad0-707766802434', 'Restaurant La Boqueria', 'dining', 41.3814776, 2.1739591, 'Carrer de la Boqueria 17, 08002 Barcelona', 90),
  ('dfa5d79b-6cca-5fcc-9279-248a42dec479', 'Restaurante La Barca del Salamanca', 'dining', 41.378613, 2.19123, 'Carrer de Pepe Rubianes, 08003 Barcelona', 90),
  ('20bbfed9-3767-5ee8-9b8a-e681fbdc0ac2', 'Salamanca', 'dining', 41.3786188, 2.19118897, 'Carrer de Pepe Rubianes, 08003 Barcelona', 90),
  ('b4058d2b-ad7a-545a-96fc-e40c0820fbb5', 'Vivo Tapas', 'dining', 41.395168, 2.15963, 'Carrer del Rosselló, 08008 Barcelona', 90),
  ('dc651a0c-c129-50bc-b79d-86cd8335222a', '100 Montaditos', 'nightlife', 41.389175, 2.172239, 'Pl. d''Urquinaona, 08010 Barcelona', 90),
  ('c8ede737-edae-5deb-83d4-a5a212e66b36', 'Bar del Pla', 'nightlife', 41.385638, 2.180039, 'Carrer de Montcada, 08003 Barcelona', 90),
  ('24abf157-2c98-5b09-a24f-85f504298f95', 'Bar El Velódromo', 'nightlife', 41.393456, 2.150122, 'C/ de Muntaner, 08036 Barcelona', 90),
  ('03836d0a-b1be-5199-b5c2-4112d381e02a', 'Bar Jai-Ca', 'nightlife', 41.381695, 2.188211, 'Carrer de Ginebra, 08003 Barcelona', 90),
  ('c2d35b47-607f-5bbc-b197-4aad7067ad8f', 'Bar Lobo', 'nightlife', 41.383396, 2.170613, 'Carrer del Pintor Fortuny, 08001 Barcelona', 90),
  ('3f615976-ee09-5274-ad95-6cc066303c4b', 'Bodega Joan', 'nightlife', 41.391715, 2.155501, 'Carrer del Rosselló, 08036 Barcelona', 90),
  ('2e07098f-fda7-557a-9b72-7075dc40be2a', 'Can Paixano', 'nightlife', 41.38178059, 2.18342685, 'Carrer de la Reina Cristina, 08003 Barcelona', 90),
  ('a5ceda1c-687b-5eca-b1c9-7cfaa8a70c02', 'Cerveseria Vaso de Oro', 'nightlife', 41.381897, 2.187249, 'Carrer de Balboa, 08003 Barcelona', 90),
  ('3618d59c-6a08-54a4-8da8-90e7e5165f49', 'El Bosc de Les Fades', 'nightlife', 41.377097, 2.177318, 'Passatge de la Banca, 08002 Barcelona', 90),
  ('48aff205-76b2-5a0c-bbaa-859d2476360b', 'El Xampanyet', 'nightlife', 41.384528, 2.181788, 'Carrer de Montcada, 08003 Barcelona', 90),
  ('3b003824-1a3c-51af-b1c5-f181e0811ac0', 'Fàbrica Moritz Barcelona', 'nightlife', 41.38254216, 2.16332691, 'Rda. de Sant Antoni, 08011 Barcelona', 90),
  ('87392bea-d4e2-56f8-b581-e02535a0433e', 'La Bombeta', 'nightlife', 41.380558, 2.187744, 'Carrer de la Maquinista, 08003 Barcelona', 90),
  ('c2b6ded1-3a51-5fea-8d19-caf3681fbd86', 'Michael Collins', 'nightlife', 41.402155, 2.172618, 'Plaça de la Sagrada Família, 08013 Barcelona', 90),
  ('42cb4d38-529f-55f9-ac9a-073c16a0668b', 'Paradiso', 'nightlife', 41.383682, 2.183691, 'Carrer de Rera Palau, 08003 Barcelona', 90),
  ('a85d0aff-f5b9-5e1b-99b8-85e4780dc826', 'Perikete', 'nightlife', 41.381403, 2.183412, 'Carrer de Llauder, 08039 Barcelona', 90),
  ('0e773b15-26f0-58cc-9af1-9e65587a5ee8', 'Quimet & Quimet', 'nightlife', 41.373989, 2.165522, 'Carrer del Poeta Cabanyes, 08004 Barcelona', 90),
  ('20b48dc4-533f-5c2b-ae62-74faea603380', 'Sheoudo Condal', 'nightlife', 41.38885554, 2.16700899, 'Rambla de Catalunya, 08007 Barcelona', 90),
  ('3c22db5e-a15b-5b48-b360-685561cd14ea', 'Tapeo', 'nightlife', 41.384571, 2.181742, 'Carrer de Montcada, 08003 Barcelona', 90),
  ('93db60cb-25df-5dca-8eef-c546a89f2ec5', 'Arc de Triomf', 'sightseeing', 41.3910282, 2.1806017, 'Passeig de Lluís Companys, 08003 Barcelona', 75),
  ('f2117be4-38e2-59b7-b380-c147a6350889', 'Barcelona Maritime Museum', 'sightseeing', 41.3753494, 2.1759332, 'Avinguada de les Drassanes, 08001 Barcelona', 75),
  ('66c56bf9-56b7-59f8-be3e-a510528d7856', 'Capella de Santa Agata', 'sightseeing', 41.3842584, 2.17753, 'Barcelona History Museum MUHBA Plaça del Rei, 08002 Barcelona', 75),
  ('ae9f8364-5da0-53a3-b827-dc0f6ac811c0', 'Casa Batlló', 'sightseeing', 41.3917078, 2.1647987, 'Passeig de Gràcia 43, 08007 Barcelona', 75),
  ('67f91705-8d09-53ad-b3aa-7d81464da775', 'Casa Vicens Gaudí', 'sightseeing', 41.4034981, 2.1506163, 'Carrer de les Carolines 20-26, 08012 Barcelona', 75),
  ('1cacd6cf-2d61-5aab-9a13-a55212437402', 'CosmoCaixa Museum of Science', 'sightseeing', 41.4132093, 2.1310839, 'Carrer d''Isaac Newton 26, 08022 Barcelona', 75),
  ('25b7d5b8-20c7-5195-81a3-05528b399353', 'Joan Miró Foundation', 'sightseeing', 41.3685997, 2.1598428, 'Parc de Montjuïc, 08038 Barcelona', 75),
  ('8cea3134-5bd8-5402-8670-dcaf64d82ffe', 'La Pedrera - Casa Milà', 'sightseeing', 41.3954442, 2.1618725, 'Passeig de Gracia 92, 08008 Barcelona', 75),
  ('d5479945-6cb8-5cd7-ab88-334bead53bef', 'Magic Fountain of Montjuïc', 'sightseeing', 41.37116665, 2.1517418, 'Pl. de Carles Buïgas, 08038 Barcelona', 75),
  ('84991060-bbfd-5bde-b4e3-1167b07c4099', 'Montjuïc Castle', 'sightseeing', 41.3633485, 2.1661443, 'Carretera de Montjuïc 66, 08038 Barcelona', 75),
  ('df075847-30e7-52c0-99df-b19540fd7d69', 'Monument a Colom', 'sightseeing', 41.3758142, 2.177766, 'Plaça Portal de la Pau, 08039 Barcelona', 75),
  ('02f96bbf-a345-527d-a5f9-616b3012ad59', 'Palau Güell', 'sightseeing', 41.37890638, 2.17420053, 'Carrer Nou de la Rambla, 08001 Barcelona', 75),
  ('0a0fe1a7-7f10-533b-a98f-8c0145845750', 'Parc del Mirador del Poble-sec', 'sightseeing', 41.37171562, 2.17187585, 'Passeig de Montjuïc, 08038 Barcelona', 75),
  ('1aac4ca1-9b7f-5509-a58c-09f95776ea53', 'Park Güell', 'sightseeing', 41.41349677861395, 2.1531057357788086, 'Barcelona, 08024 Barcelona', 75),
  ('11c34e22-c882-579e-b0bb-462f6524f865', 'Plaça d''Espanya', 'sightseeing', 41.375034, 2.149124, 'Pl. d''Espanya, 08004 Barcelona', 75),
  ('6d7f9975-84db-525b-afd6-aee165e25860', 'Plaça de Catalunya', 'sightseeing', 41.3869694, 2.1700134, '08002 Barcelona', 75),
  ('040b4a3c-cb7e-53f9-9e02-da4540f52200', 'Poble Espanyol', 'sightseeing', 41.3687206, 2.1484248, 'Avinguda de Francesc Ferrer i Guàrdia 13, 08038 Barcelona', 75),
  ('0d2475ad-cf89-5186-b6bc-879c7c039bbe', 'Sant Pau Recinte Modernista', 'sightseeing', 41.4118682, 2.1743061, 'Carrer de Sant Antoni Maria Claret 167, 08025 Barcelona', 75)
on conflict (id) do update set
  name              = excluded.name,
  category          = excluded.category,
  lat               = excluded.lat,
  lng               = excluded.lng,
  address           = excluded.address,
  avg_visit_minutes = excluded.avg_visit_minutes;
