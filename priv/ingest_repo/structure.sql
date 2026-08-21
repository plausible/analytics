CREATE TABLE plausible_events_db.sessions_v2_tmp_versioned
(
    `session_id` UInt64,
    `sign` Int8,
    `site_id` UInt64,
    `user_id` UInt64,
    `hostname` String CODEC(ZSTD(3)),
    `timestamp` DateTime CODEC(Delta(4), LZ4),
    `start` DateTime CODEC(Delta(4), LZ4),
    `is_bounce` UInt8,
    `entry_page` String CODEC(ZSTD(3)),
    `exit_page` String CODEC(ZSTD(3)),
    `pageviews` Int32,
    `events` Int32,
    `duration` UInt32,
    `referrer` String CODEC(ZSTD(3)),
    `referrer_source` String CODEC(ZSTD(3)),
    `country_code` LowCardinality(FixedString(2)),
    `screen_size` LowCardinality(String),
    `operating_system` LowCardinality(String),
    `browser` LowCardinality(String),
    `utm_medium` String CODEC(ZSTD(3)),
    `utm_source` String CODEC(ZSTD(3)),
    `utm_campaign` String CODEC(ZSTD(3)),
    `browser_version` LowCardinality(String),
    `operating_system_version` LowCardinality(String),
    `subdivision1_code` LowCardinality(String),
    `subdivision2_code` LowCardinality(String),
    `city_geoname_id` UInt32,
    `utm_content` String CODEC(ZSTD(3)),
    `utm_term` String CODEC(ZSTD(3)),
    `transferred_from` String,
    `entry_meta.key` Array(String) CODEC(ZSTD(3)),
    `entry_meta.value` Array(String) CODEC(ZSTD(3)),
    INDEX minmax_timestamp timestamp TYPE minmax GRANULARITY 1
)
ENGINE = CollapsingMergeTree(sign)
PARTITION BY toYYYYMM(start)
PRIMARY KEY (site_id, toDate(start), user_id, session_id)
ORDER BY (site_id, toDate(start), user_id, session_id)
SAMPLE BY user_id
SETTINGS index_granularity = 8192;

CREATE TABLE plausible_events_db.sessions_v2
(
    `session_id` UInt64,
    `sign` Int8,
    `site_id` UInt64,
    `user_id` UInt64,
    `hostname` String CODEC(ZSTD(3)),
    `timestamp` DateTime CODEC(Delta(4), LZ4),
    `start` DateTime CODEC(Delta(4), LZ4),
    `is_bounce` UInt8,
    `entry_page` String CODEC(ZSTD(3)),
    `exit_page` String CODEC(ZSTD(3)),
    `pageviews` Int32,
    `events` Int32,
    `duration` UInt32,
    `referrer` String CODEC(ZSTD(3)),
    `referrer_source` String CODEC(ZSTD(3)),
    `country_code` LowCardinality(FixedString(2)),
    `screen_size` LowCardinality(String),
    `operating_system` LowCardinality(String),
    `browser` LowCardinality(String),
    `utm_medium` String CODEC(ZSTD(3)),
    `utm_source` String CODEC(ZSTD(3)),
    `utm_campaign` String CODEC(ZSTD(3)),
    `browser_version` LowCardinality(String),
    `operating_system_version` LowCardinality(String),
    `subdivision1_code` LowCardinality(String),
    `subdivision2_code` LowCardinality(String),
    `city_geoname_id` UInt32,
    `utm_content` String CODEC(ZSTD(3)),
    `utm_term` String CODEC(ZSTD(3)),
    `transferred_from` String,
    `entry_meta.key` Array(String) CODEC(ZSTD(3)),
    `entry_meta.value` Array(String) CODEC(ZSTD(3)),
    `exit_page_hostname` String CODEC(ZSTD(3)),
    `city` UInt32 ALIAS city_geoname_id,
    `country` LowCardinality(FixedString(2)) ALIAS country_code,
    `device` LowCardinality(String) ALIAS screen_size,
    `entry_page_hostname` String ALIAS hostname,
    `os` LowCardinality(String) ALIAS operating_system,
    `os_version` LowCardinality(String) ALIAS operating_system_version,
    `region` LowCardinality(String) ALIAS subdivision1_code,
    `screen` LowCardinality(String) ALIAS screen_size,
    `source` String ALIAS referrer_source,
    `country_name` String ALIAS dictGet('plausible_events_db.location_data_dict', 'name', ('country', country_code)),
    `region_name` String ALIAS dictGet('plausible_events_db.location_data_dict', 'name', ('subdivision', subdivision1_code)),
    `city_name` String ALIAS dictGet('plausible_events_db.location_data_dict', 'name', ('city', city_geoname_id)),
    `channel` LowCardinality(String),
    `click_id_param` LowCardinality(String),
    `acquisition_channel` LowCardinality(String) MATERIALIZED multiIf(position(lower(utm_campaign), 'cross-network') > 0, 'Cross-network', lower(utm_medium) IN ('display', 'banner', 'expandable', 'interstitial', 'cpm'), 'Display', match(lower(utm_medium), '^(.*cp.*|ppc|retargeting|paid.*)$') AND ((dictGet('plausible_events_db.acquisition_channel_source_category_dict', 'category', lower(referrer_source)) = 'SOURCE_CATEGORY_SHOPPING') OR match(lower(utm_campaign), '^(.*(([^a-df-z]|^)shop|shopping).*)$')), 'Paid Shopping', ((dictGet('plausible_events_db.acquisition_channel_source_category_dict', 'category', lower(referrer_source)) = 'SOURCE_CATEGORY_SEARCH') AND (match(lower(utm_medium), '^(.*cp.*|ppc|retargeting|paid.*)$') OR dictHas('plausible_events_db.acquisition_channel_paid_sources_dict', lower(utm_source)))) OR ((lower(referrer_source) = 'google') AND (click_id_param = 'gclid')) OR ((lower(referrer_source) = 'bing') AND (click_id_param = 'msclkid')), 'Paid Search', (dictGet('plausible_events_db.acquisition_channel_source_category_dict', 'category', lower(referrer_source)) = 'SOURCE_CATEGORY_SOCIAL') AND (match(lower(utm_medium), '^(.*cp.*|ppc|retargeting|paid.*)$') OR dictHas('plausible_events_db.acquisition_channel_paid_sources_dict', lower(utm_source))), 'Paid Social', (dictGet('plausible_events_db.acquisition_channel_source_category_dict', 'category', lower(referrer_source)) = 'SOURCE_CATEGORY_VIDEO') AND (match(lower(utm_medium), '^(.*cp.*|ppc|retargeting|paid.*)$') OR dictHas('plausible_events_db.acquisition_channel_paid_sources_dict', lower(utm_source))), 'Paid Video', match(lower(utm_medium), '^(.*cp.*|ppc|retargeting|paid.*)$'), 'Paid Other', (dictGet('plausible_events_db.acquisition_channel_source_category_dict', 'category', lower(referrer_source)) = 'SOURCE_CATEGORY_SHOPPING') OR match(lower(utm_campaign), '^(.*(([^a-df-z]|^)shop|shopping).*)$'), 'Organic Shopping', (dictGet('plausible_events_db.acquisition_channel_source_category_dict', 'category', lower(referrer_source)) = 'SOURCE_CATEGORY_SOCIAL') OR (lower(utm_medium) IN ('social', 'social-network', 'social-media', 'sm', 'social network', 'social media')), 'Organic Social', (dictGet('plausible_events_db.acquisition_channel_source_category_dict', 'category', lower(referrer_source)) = 'SOURCE_CATEGORY_VIDEO') OR (position(lower(utm_medium), 'video') > 0), 'Organic Video', dictGet('plausible_events_db.acquisition_channel_source_category_dict', 'category', lower(referrer_source)) = 'SOURCE_CATEGORY_SEARCH', 'Organic Search', (dictGet('plausible_events_db.acquisition_channel_source_category_dict', 'category', lower(referrer_source)) = 'SOURCE_CATEGORY_EMAIL') OR match(lower(utm_source), 'e[-_ ]?mail|newsletter') OR match(lower(utm_medium), 'e[-_ ]?mail|newsletter'), 'Email', lower(utm_medium) = 'affiliate', 'Affiliates', lower(utm_medium) = 'audio', 'Audio', lower(utm_source) = 'sms', 'SMS', lower(utm_medium) = 'sms', 'SMS', endsWith(lower(utm_medium), 'push') OR multiSearchAny(lower(utm_medium), ['mobile', 'notification']) OR (lower(referrer_source) = 'firebase'), 'Mobile Push Notifications', (lower(utm_medium) IN ('referral', 'app', 'link')) OR (NOT empty(lower(referrer_source))), 'Referral', 'Direct'),
    `batch` UInt64,
    INDEX minmax_timestamp timestamp TYPE minmax GRANULARITY 1,
    INDEX minmax_batch batch TYPE minmax GRANULARITY 1
)
ENGINE = VersionedCollapsingMergeTree(sign, events)
PARTITION BY toYYYYMM(start)
PRIMARY KEY (site_id, toDate(start), user_id, session_id)
ORDER BY (site_id, toDate(start), user_id, session_id)
SAMPLE BY user_id
SETTINGS index_granularity = 8192;

CREATE DICTIONARY plausible_events_db.location_data_dict
(
    `type` String,
    `id` String,
    `name` String
)
PRIMARY KEY type, id
SOURCE(CLICKHOUSE(TABLE location_data DB 'plausible_events_db'))
LIFETIME(MIN 0 MAX 0)
LAYOUT(COMPLEX_KEY_CACHE(SIZE_IN_CELLS 500000));

CREATE TABLE plausible_events_db.location_data
(
    `type` LowCardinality(String),
    `id` String,
    `name` String
)
ENGINE = MergeTree
ORDER BY (type, id)
SETTINGS index_granularity = 128
COMMENT '2024-07-09';

CREATE TABLE plausible_events_db.ingest_counters
(
    `event_timebucket` DateTime,
    `domain` LowCardinality(String),
    `site_id` Nullable(UInt64),
    `metric` LowCardinality(String),
    `value` UInt64,
    `tracker_script_version` UInt16,
    PROJECTION ingest_counters_site_traffic_projection
    (
        SELECT 
            site_id,
            toDate(event_timebucket),
            sumIf(value, metric = 'buffered')
        GROUP BY 
            site_id,
            toDate(event_timebucket)
    )
)
ENGINE = SummingMergeTree(value)
PRIMARY KEY (domain, toDate(event_timebucket), metric, toStartOfMinute(event_timebucket))
ORDER BY (domain, toDate(event_timebucket), metric, toStartOfMinute(event_timebucket), tracker_script_version)
SETTINGS index_granularity = 8192, deduplicate_merge_projection_mode = 'rebuild';

CREATE TABLE plausible_events_db.imported_visitors
(
    `site_id` UInt64,
    `date` Date,
    `visitors` UInt64,
    `pageviews` UInt64,
    `bounces` UInt64,
    `visits` UInt64,
    `visit_duration` UInt64,
    `import_id` UInt64
)
ENGINE = MergeTree
ORDER BY (site_id, date)
SETTINGS index_granularity = 8192, replicated_deduplication_window = 0;

CREATE TABLE plausible_events_db.imported_sources
(
    `site_id` UInt64,
    `date` Date,
    `source` String,
    `utm_medium` String,
    `utm_campaign` String,
    `utm_content` String,
    `utm_term` String,
    `visitors` UInt64,
    `visits` UInt64,
    `visit_duration` UInt64,
    `bounces` UInt32,
    `import_id` UInt64,
    `pageviews` UInt64,
    `referrer` String,
    `utm_source` String,
    `channel` LowCardinality(String)
)
ENGINE = MergeTree
ORDER BY (site_id, date, source)
SETTINGS index_granularity = 8192, replicated_deduplication_window = 0;

CREATE TABLE plausible_events_db.imported_pages
(
    `site_id` UInt64,
    `date` Date,
    `hostname` String,
    `page` String,
    `visitors` UInt64,
    `pageviews` UInt64,
    `exits` UInt64,
    `import_id` UInt64,
    `visits` UInt64,
    `total_scroll_depth` UInt64,
    `total_scroll_depth_visits` UInt64,
    `total_time_on_page` UInt64,
    `total_time_on_page_visits` UInt64
)
ENGINE = MergeTree
ORDER BY (site_id, date, hostname, page)
SETTINGS index_granularity = 8192, replicated_deduplication_window = 0;

CREATE TABLE plausible_events_db.imported_operating_systems
(
    `site_id` UInt64,
    `date` Date,
    `operating_system` String,
    `visitors` UInt64,
    `visits` UInt64,
    `visit_duration` UInt64,
    `bounces` UInt32,
    `import_id` UInt64,
    `pageviews` UInt64,
    `operating_system_version` String
)
ENGINE = MergeTree
ORDER BY (site_id, date, operating_system)
SETTINGS index_granularity = 8192, replicated_deduplication_window = 0;

CREATE TABLE plausible_events_db.imported_locations
(
    `site_id` UInt64,
    `date` Date,
    `country` String,
    `region` String,
    `city` UInt64,
    `visitors` UInt64,
    `visits` UInt64,
    `visit_duration` UInt64,
    `bounces` UInt32,
    `import_id` UInt64,
    `pageviews` UInt64,
    `country_name` String ALIAS dictGet('plausible_events_db.location_data_dict', 'name', ('country', country)),
    `region_name` String ALIAS dictGet('plausible_events_db.location_data_dict', 'name', ('subdivision', region)),
    `city_name` String ALIAS dictGet('plausible_events_db.location_data_dict', 'name', ('city', city))
)
ENGINE = MergeTree
ORDER BY (site_id, date, country, region, city)
SETTINGS index_granularity = 8192, replicated_deduplication_window = 0;

CREATE TABLE plausible_events_db.imported_exit_pages
(
    `site_id` UInt64,
    `date` Date,
    `exit_page` String,
    `visitors` UInt64,
    `exits` UInt64,
    `import_id` UInt64,
    `pageviews` UInt64,
    `bounces` UInt32,
    `visit_duration` UInt64
)
ENGINE = MergeTree
ORDER BY (site_id, date, exit_page)
SETTINGS index_granularity = 8192, replicated_deduplication_window = 0;

CREATE TABLE plausible_events_db.imported_entry_pages
(
    `site_id` UInt64,
    `date` Date,
    `entry_page` String,
    `visitors` UInt64,
    `entrances` UInt64,
    `visit_duration` UInt64,
    `bounces` UInt32,
    `import_id` UInt64,
    `pageviews` UInt64
)
ENGINE = MergeTree
ORDER BY (site_id, date, entry_page)
SETTINGS index_granularity = 8192, replicated_deduplication_window = 0;

CREATE TABLE plausible_events_db.imported_devices
(
    `site_id` UInt64,
    `date` Date,
    `device` String,
    `visitors` UInt64,
    `visits` UInt64,
    `visit_duration` UInt64,
    `bounces` UInt32,
    `import_id` UInt64,
    `pageviews` UInt64
)
ENGINE = MergeTree
ORDER BY (site_id, date, device)
SETTINGS index_granularity = 8192, replicated_deduplication_window = 0;

CREATE TABLE plausible_events_db.imported_custom_events
(
    `site_id` UInt64,
    `import_id` UInt64,
    `date` Date,
    `name` String CODEC(ZSTD(3)),
    `link_url` String CODEC(ZSTD(3)),
    `path` String CODEC(ZSTD(3)),
    `visitors` UInt64,
    `events` UInt64
)
ENGINE = MergeTree
ORDER BY (site_id, import_id, date, name)
SETTINGS replicated_deduplication_window = 0, index_granularity = 8192;

CREATE TABLE plausible_events_db.imported_browsers
(
    `site_id` UInt64,
    `date` Date,
    `browser` String,
    `visitors` UInt64,
    `visits` UInt64,
    `visit_duration` UInt64,
    `bounces` UInt32,
    `import_id` UInt64,
    `pageviews` UInt64,
    `browser_version` String
)
ENGINE = MergeTree
ORDER BY (site_id, date, browser)
SETTINGS index_granularity = 8192, replicated_deduplication_window = 0;

CREATE DICTIONARY plausible_events_db.failed_batches_dict
(
    `batch` UInt64
)
PRIMARY KEY batch
SOURCE(CLICKHOUSE(TABLE failed_batches DB 'plausible_events_db' INVALIDATE_QUERY 'SELECT max(batch) FROM failed_batches'))
LIFETIME(MIN 300 MAX 360)
LAYOUT(HASHED());

CREATE TABLE plausible_events_db.failed_batches
(
    `batch` UInt64
)
ENGINE = MergeTree
ORDER BY batch
SETTINGS index_granularity = 8192;

CREATE TABLE plausible_events_db.events_v2
(
    `timestamp` DateTime CODEC(Delta(4), LZ4),
    `name` LowCardinality(String),
    `site_id` UInt64,
    `user_id` UInt64,
    `session_id` UInt64,
    `hostname` String CODEC(ZSTD(3)),
    `pathname` String CODEC(ZSTD(3)),
    `referrer` String CODEC(ZSTD(3)),
    `referrer_source` String CODEC(ZSTD(3)),
    `country_code` FixedString(2),
    `screen_size` LowCardinality(String),
    `operating_system` LowCardinality(String),
    `browser` LowCardinality(String),
    `utm_medium` String CODEC(ZSTD(3)),
    `utm_source` String CODEC(ZSTD(3)),
    `utm_campaign` String CODEC(ZSTD(3)),
    `meta.key` Array(String) CODEC(ZSTD(3)),
    `meta.value` Array(String) CODEC(ZSTD(3)),
    `browser_version` LowCardinality(String),
    `operating_system_version` LowCardinality(String),
    `subdivision1_code` LowCardinality(String),
    `subdivision2_code` LowCardinality(String),
    `city_geoname_id` UInt32,
    `utm_content` String CODEC(ZSTD(3)),
    `utm_term` String CODEC(ZSTD(3)),
    `revenue_reporting_amount` Nullable(Decimal(18, 3)),
    `revenue_reporting_currency` FixedString(3),
    `revenue_source_amount` Nullable(Decimal(18, 3)),
    `revenue_source_currency` FixedString(3),
    `city` UInt32 ALIAS city_geoname_id,
    `country` LowCardinality(FixedString(2)) ALIAS country_code,
    `device` LowCardinality(String) ALIAS screen_size,
    `os` LowCardinality(String) ALIAS operating_system,
    `os_version` LowCardinality(String) ALIAS operating_system_version,
    `region` LowCardinality(String) ALIAS subdivision1_code,
    `screen` LowCardinality(String) ALIAS screen_size,
    `source` String ALIAS referrer_source,
    `country_name` String ALIAS dictGet('plausible_events_db.location_data_dict', 'name', ('country', country_code)),
    `region_name` String ALIAS dictGet('plausible_events_db.location_data_dict', 'name', ('subdivision', subdivision1_code)),
    `city_name` String ALIAS dictGet('plausible_events_db.location_data_dict', 'name', ('city', city_geoname_id)),
    `channel` LowCardinality(String),
    `click_id_param` LowCardinality(String),
    `scroll_depth` UInt8,
    `acquisition_channel` LowCardinality(String) MATERIALIZED multiIf(position(lower(utm_campaign), 'cross-network') > 0, 'Cross-network', lower(utm_medium) IN ('display', 'banner', 'expandable', 'interstitial', 'cpm'), 'Display', match(lower(utm_medium), '^(.*cp.*|ppc|retargeting|paid.*)$') AND ((dictGet('plausible_events_db.acquisition_channel_source_category_dict', 'category', lower(referrer_source)) = 'SOURCE_CATEGORY_SHOPPING') OR match(lower(utm_campaign), '^(.*(([^a-df-z]|^)shop|shopping).*)$')), 'Paid Shopping', ((dictGet('plausible_events_db.acquisition_channel_source_category_dict', 'category', lower(referrer_source)) = 'SOURCE_CATEGORY_SEARCH') AND (match(lower(utm_medium), '^(.*cp.*|ppc|retargeting|paid.*)$') OR dictHas('plausible_events_db.acquisition_channel_paid_sources_dict', lower(utm_source)))) OR ((lower(referrer_source) = 'google') AND (click_id_param = 'gclid')) OR ((lower(referrer_source) = 'bing') AND (click_id_param = 'msclkid')), 'Paid Search', (dictGet('plausible_events_db.acquisition_channel_source_category_dict', 'category', lower(referrer_source)) = 'SOURCE_CATEGORY_SOCIAL') AND (match(lower(utm_medium), '^(.*cp.*|ppc|retargeting|paid.*)$') OR dictHas('plausible_events_db.acquisition_channel_paid_sources_dict', lower(utm_source))), 'Paid Social', (dictGet('plausible_events_db.acquisition_channel_source_category_dict', 'category', lower(referrer_source)) = 'SOURCE_CATEGORY_VIDEO') AND (match(lower(utm_medium), '^(.*cp.*|ppc|retargeting|paid.*)$') OR dictHas('plausible_events_db.acquisition_channel_paid_sources_dict', lower(utm_source))), 'Paid Video', match(lower(utm_medium), '^(.*cp.*|ppc|retargeting|paid.*)$'), 'Paid Other', (dictGet('plausible_events_db.acquisition_channel_source_category_dict', 'category', lower(referrer_source)) = 'SOURCE_CATEGORY_SHOPPING') OR match(lower(utm_campaign), '^(.*(([^a-df-z]|^)shop|shopping).*)$'), 'Organic Shopping', (dictGet('plausible_events_db.acquisition_channel_source_category_dict', 'category', lower(referrer_source)) = 'SOURCE_CATEGORY_SOCIAL') OR (lower(utm_medium) IN ('social', 'social-network', 'social-media', 'sm', 'social network', 'social media')), 'Organic Social', (dictGet('plausible_events_db.acquisition_channel_source_category_dict', 'category', lower(referrer_source)) = 'SOURCE_CATEGORY_VIDEO') OR (position(lower(utm_medium), 'video') > 0), 'Organic Video', dictGet('plausible_events_db.acquisition_channel_source_category_dict', 'category', lower(referrer_source)) = 'SOURCE_CATEGORY_SEARCH', 'Organic Search', (dictGet('plausible_events_db.acquisition_channel_source_category_dict', 'category', lower(referrer_source)) = 'SOURCE_CATEGORY_EMAIL') OR match(lower(utm_source), 'e[-_ ]?mail|newsletter') OR match(lower(utm_medium), 'e[-_ ]?mail|newsletter'), 'Email', lower(utm_medium) = 'affiliate', 'Affiliates', lower(utm_medium) = 'audio', 'Audio', lower(utm_source) = 'sms', 'SMS', lower(utm_medium) = 'sms', 'SMS', endsWith(lower(utm_medium), 'push') OR multiSearchAny(lower(utm_medium), ['mobile', 'notification']) OR (lower(referrer_source) = 'firebase'), 'Mobile Push Notifications', (lower(utm_medium) IN ('referral', 'app', 'link')) OR (NOT empty(lower(referrer_source))), 'Referral', 'Direct'),
    `engagement_time` UInt32,
    `batch` UInt64,
    INDEX minmax_batch batch TYPE minmax GRANULARITY 1
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(timestamp)
PRIMARY KEY (site_id, toDate(timestamp), name, user_id)
ORDER BY (site_id, toDate(timestamp), name, user_id, timestamp)
SAMPLE BY user_id
SETTINGS index_granularity = 8192;

CREATE DICTIONARY plausible_events_db.acquisition_channel_source_category_dict
(
    `referrer_source` String,
    `category` String
)
PRIMARY KEY referrer_source
SOURCE(CLICKHOUSE(TABLE acquisition_channel_source_category DB 'plausible_events_db'))
LIFETIME(MIN 0 MAX 0)
LAYOUT(COMPLEX_KEY_HASHED());

CREATE TABLE plausible_events_db.acquisition_channel_source_category
(
    `referrer_source` String,
    `category` LowCardinality(String)
)
ENGINE = MergeTree
ORDER BY referrer_source
SETTINGS index_granularity = 8192;

CREATE DICTIONARY plausible_events_db.acquisition_channel_paid_sources_dict
(
    `referrer_source` String
)
PRIMARY KEY referrer_source
SOURCE(CLICKHOUSE(TABLE acquisition_channel_paid_sources DB 'plausible_events_db'))
LIFETIME(MIN 0 MAX 0)
LAYOUT(COMPLEX_KEY_HASHED());

CREATE TABLE plausible_events_db.acquisition_channel_paid_sources
(
    `referrer_source` String
)
ENGINE = MergeTree
ORDER BY referrer_source
SETTINGS index_granularity = 8192;

CREATE TABLE plausible_events_db.schema_migrations
(
    `version` Int64,
    `inserted_at` DateTime
)
ENGINE = TinyLog;

CREATE DICTIONARY plausible_events_db.location_data_dict
(
    `type` String,
    `id` String,
    `name` String
)
PRIMARY KEY type, id
SOURCE(CLICKHOUSE(TABLE location_data DB 'plausible_events_db'))
LIFETIME(MIN 0 MAX 0)
LAYOUT(COMPLEX_KEY_CACHE(SIZE_IN_CELLS 500000));

CREATE DICTIONARY plausible_events_db.failed_batches_dict
(
    `batch` UInt64
)
PRIMARY KEY batch
SOURCE(CLICKHOUSE(TABLE failed_batches DB 'plausible_events_db' INVALIDATE_QUERY 'SELECT max(batch) FROM failed_batches'))
LIFETIME(MIN 300 MAX 360)
LAYOUT(HASHED());

CREATE DICTIONARY plausible_events_db.acquisition_channel_source_category_dict
(
    `referrer_source` String,
    `category` String
)
PRIMARY KEY referrer_source
SOURCE(CLICKHOUSE(TABLE acquisition_channel_source_category DB 'plausible_events_db'))
LIFETIME(MIN 0 MAX 0)
LAYOUT(COMPLEX_KEY_HASHED());

CREATE DICTIONARY plausible_events_db.acquisition_channel_paid_sources_dict
(
    `referrer_source` String
)
PRIMARY KEY referrer_source
SOURCE(CLICKHOUSE(TABLE acquisition_channel_paid_sources DB 'plausible_events_db'))
LIFETIME(MIN 0 MAX 0)
LAYOUT(COMPLEX_KEY_HASHED());

INSERT INTO "plausible_events_db"."schema_migrations" (version, inserted_at) VALUES
(20200915070607,'2025-09-12 16:26:41'),
(20200918075025,'2025-09-12 16:26:41'),
(20201020083739,'2025-09-12 16:26:41'),
(20201106125234,'2025-09-12 16:26:41'),
(20210323130440,'2025-09-12 16:26:41'),
(20210712214034,'2025-09-12 16:26:41'),
(20211017093035,'2025-09-12 16:26:41'),
(20211112130238,'2025-09-12 16:26:41'),
(20220310104931,'2025-09-12 16:26:41'),
(20220404123000,'2025-09-12 16:26:41'),
(20220421161259,'2025-09-12 16:26:41'),
(20220422075510,'2025-09-12 16:26:41'),
(20230124140348,'2025-09-12 16:26:41'),
(20230210140348,'2025-09-12 16:26:41'),
(20230214114402,'2025-09-12 16:26:41'),
(20230320094327,'2025-09-12 16:26:41'),
(20230417104025,'2025-09-12 16:26:41'),
(20230509124919,'2025-09-12 16:26:41'),
(20231017073642,'2025-09-12 16:26:41'),
(20240123142959,'2025-09-12 16:26:41'),
(20240209085338,'2025-09-12 16:26:41'),
(20240220123656,'2025-09-12 16:26:41'),
(20240222082911,'2025-09-12 16:26:41'),
(20240305085310,'2025-09-12 16:26:41'),
(20240326134840,'2025-09-12 16:26:41'),
(20240327085855,'2025-09-12 16:26:41'),
(20240419133926,'2025-09-12 16:26:41'),
(20240423094014,'2025-09-12 16:26:41'),
(20240502115822,'2025-09-12 16:26:41'),
(20240709181437,'2025-09-12 16:26:42'),
(20240801091615,'2025-09-12 16:26:42'),
(20240829092858,'2025-09-12 16:26:42'),
(20241020114559,'2025-09-12 16:26:42'),
(20241028142653,'2025-09-12 16:26:42'),
(20241029074741,'2025-09-12 16:26:42'),
(20241104082248,'2025-09-12 16:26:42'),
(20241111084056,'2025-09-12 16:26:42'),
(20241112222848,'2025-09-12 16:26:42'),
(20241118112238,'2025-09-12 16:26:42'),
(20241120064325,'2025-09-12 16:26:42'),
(20241216133031,'2025-09-12 16:26:42'),
(20241218102326,'2025-09-12 16:26:42'),
(20241231083407,'2025-09-12 16:26:42'),
(20250212100953,'2025-09-12 16:26:42'),
(20250218094453,'2025-09-12 16:26:42'),
(20250219093806,'2025-09-12 16:26:42'),
(20250221124625,'2025-09-12 16:26:42'),
(20250304074501,'2025-09-12 16:26:42'),
(20250312063938,'2025-09-12 16:26:42'),
(20250316182725,'2025-09-12 16:26:42'),
(20250911084719,'2025-09-12 16:26:42'),
(20250912094034,'2025-09-12 16:26:42');
