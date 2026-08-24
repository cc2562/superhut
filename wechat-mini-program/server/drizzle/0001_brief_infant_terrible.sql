CREATE TABLE `announcement_reads` (
	`announcement_id` varchar(36) NOT NULL,
	`user_id` varchar(36) NOT NULL,
	`read_at` datetime(3) NOT NULL,
	CONSTRAINT `announcement_reads_announcement_id_user_id_pk` PRIMARY KEY(`announcement_id`,`user_id`)
);
--> statement-breakpoint
CREATE TABLE `announcements` (
	`id` varchar(36) NOT NULL,
	`title` varchar(80) NOT NULL,
	`summary` varchar(160) NOT NULL,
	`content` longtext NOT NULL,
	`status` enum('draft','scheduled','published','withdrawn') NOT NULL DEFAULT 'draft',
	`action_path` varchar(255),
	`publish_at` datetime(3),
	`expires_at` datetime(3),
	`created_by_user_id` varchar(36),
	`created_at` datetime(3) NOT NULL,
	`updated_at` datetime(3) NOT NULL,
	CONSTRAINT `announcements_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
ALTER TABLE `announcement_reads` ADD CONSTRAINT `announcement_reads_announcement_id_announcements_id_fk` FOREIGN KEY (`announcement_id`) REFERENCES `announcements`(`id`) ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `announcement_reads` ADD CONSTRAINT `announcement_reads_user_id_users_id_fk` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE `announcements` ADD CONSTRAINT `announcements_created_by_user_id_users_id_fk` FOREIGN KEY (`created_by_user_id`) REFERENCES `users`(`id`) ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX `announcement_reads_user_idx` ON `announcement_reads` (`user_id`,`read_at`);--> statement-breakpoint
CREATE INDEX `announcements_visibility_idx` ON `announcements` (`status`,`publish_at`,`expires_at`);