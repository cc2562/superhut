CREATE TABLE `academic_bindings` (
	`id` varchar(36) NOT NULL,
	`user_id` varchar(36) NOT NULL,
	`student_id_hash` varchar(64) NOT NULL,
	`student_id_ciphertext` text NOT NULL,
	`token_ciphertext` text NOT NULL,
	`token_key_version` varchar(32) NOT NULL,
	`display_name` varchar(128),
	`academy_name` varchar(256),
	`class_name` varchar(256),
	`entrance_year` varchar(16),
	`status` enum('active','expired','unbound') NOT NULL DEFAULT 'active',
	`last_verified_at` datetime(3),
	`created_at` datetime(3) NOT NULL,
	`updated_at` datetime(3) NOT NULL,
	CONSTRAINT `academic_bindings_id` PRIMARY KEY(`id`),
	CONSTRAINT `academic_bindings_user_uq` UNIQUE(`user_id`)
);
--> statement-breakpoint
CREATE TABLE `academic_snapshots` (
	`id` varchar(36) NOT NULL,
	`user_id` varchar(36) NOT NULL,
	`kind` enum('timetable','scores','exams') NOT NULL,
	`semester_id` varchar(128) NOT NULL DEFAULT '',
	`payload_ciphertext` longtext NOT NULL,
	`source_updated_at` datetime(3),
	`fetched_at` datetime(3) NOT NULL,
	`expires_at` datetime(3) NOT NULL,
	CONSTRAINT `academic_snapshots_id` PRIMARY KEY(`id`),
	CONSTRAINT `academic_snapshots_lookup_uq` UNIQUE(`user_id`,`kind`,`semester_id`)
);
--> statement-breakpoint
CREATE TABLE `audit_events` (
	`id` varchar(36) NOT NULL,
	`anonymous_user_id` varchar(64),
	`event_type` varchar(128) NOT NULL,
	`result` varchar(32) NOT NULL,
	`request_id` varchar(128) NOT NULL,
	`upstream_status_class` varchar(16),
	`metadata` json,
	`created_at` datetime(3) NOT NULL,
	CONSTRAINT `audit_events_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `privacy_consents` (
	`user_id` varchar(36) NOT NULL,
	`version` varchar(32) NOT NULL,
	`accepted_at` datetime(3) NOT NULL,
	CONSTRAINT `privacy_consents_user_id_version_pk` PRIMARY KEY(`user_id`,`version`)
);
--> statement-breakpoint
CREATE TABLE `rate_limits` (
	`key` varchar(128) NOT NULL,
	`attempts` int NOT NULL,
	`resets_at` datetime(3) NOT NULL,
	`updated_at` datetime(3) NOT NULL,
	CONSTRAINT `rate_limits_key` PRIMARY KEY(`key`)
);
--> statement-breakpoint
CREATE TABLE `runtime_cache` (
	`key` varchar(255) NOT NULL,
	`payload` longtext NOT NULL,
	`expires_at` datetime(3) NOT NULL,
	`updated_at` datetime(3) NOT NULL,
	CONSTRAINT `runtime_cache_key` PRIMARY KEY(`key`)
);
--> statement-breakpoint
CREATE TABLE `sessions` (
	`id` varchar(36) NOT NULL,
	`user_id` varchar(36) NOT NULL,
	`access_token_hash` varchar(64) NOT NULL,
	`refresh_token_hash` varchar(64) NOT NULL,
	`access_expires_at` datetime(3) NOT NULL,
	`refresh_expires_at` datetime(3) NOT NULL,
	`revoked_at` datetime(3),
	`created_at` datetime(3) NOT NULL,
	CONSTRAINT `sessions_id` PRIMARY KEY(`id`),
	CONSTRAINT `sessions_access_hash_uq` UNIQUE(`access_token_hash`),
	CONSTRAINT `sessions_refresh_hash_uq` UNIQUE(`refresh_token_hash`)
);
--> statement-breakpoint
CREATE TABLE `users` (
	`id` varchar(36) NOT NULL,
	`openid_hash` varchar(64) NOT NULL,
	`openid_ciphertext` text NOT NULL,
	`unionid_ciphertext` text,
	`status` enum('active','deleted','blocked') NOT NULL DEFAULT 'active',
	`created_at` datetime(3) NOT NULL,
	`updated_at` datetime(3) NOT NULL,
	`deleted_at` datetime(3),
	CONSTRAINT `users_id` PRIMARY KEY(`id`),
	CONSTRAINT `users_openid_hash_uq` UNIQUE(`openid_hash`)
);
--> statement-breakpoint
ALTER TABLE `academic_bindings` ADD CONSTRAINT `academic_bindings_user_id_users_id_fk` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `academic_snapshots` ADD CONSTRAINT `academic_snapshots_user_id_users_id_fk` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `privacy_consents` ADD CONSTRAINT `privacy_consents_user_id_users_id_fk` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `sessions` ADD CONSTRAINT `sessions_user_id_users_id_fk` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX `academic_bindings_student_hash_idx` ON `academic_bindings` (`student_id_hash`);--> statement-breakpoint
CREATE INDEX `audit_events_created_at_idx` ON `audit_events` (`created_at`);--> statement-breakpoint
CREATE INDEX `sessions_user_idx` ON `sessions` (`user_id`);