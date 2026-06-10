-- 数字人核心数据库设计（MySQL 8.0+）
-- 说明：
-- 1) 采用 utf8mb4，支持多语言与表情字符
-- 2) 以“最小可用”模型为目标，便于后续扩展
-- 3) JSON 字段用于承载可变结构（如 L3/L4/L5）

CREATE DATABASE IF NOT EXISTS `ai_world`
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE `ai_world`;

-- 1. 用户表（对话用户）
CREATE TABLE IF NOT EXISTS `aw_user` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `external_user_id` VARCHAR(64) NOT NULL COMMENT '业务侧用户ID',
  `nickname` VARCHAR(64) NULL COMMENT '昵称',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 1启用 0禁用',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_aw_user_external_user_id` (`external_user_id`),
  KEY `idx_aw_user_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='对话用户';

-- 2. 数字人主表（角色主档）
CREATE TABLE IF NOT EXISTS `aw_digital_human` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `code` VARCHAR(64) NOT NULL COMMENT '角色编码(唯一)',
  `name` VARCHAR(64) NOT NULL COMMENT '角色名称',
  `avatar_url` VARCHAR(512) NULL COMMENT '头像URL',
  `description` VARCHAR(255) NULL COMMENT '角色简介',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 1上线 0下线',
  `current_persona_version_id` BIGINT UNSIGNED NULL COMMENT '当前生效人设版本ID',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_aw_digital_human_code` (`code`),
  KEY `idx_aw_digital_human_current_pv` (`current_persona_version_id`),
  KEY `idx_aw_digital_human_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='数字人角色主档';

-- 3. 人设版本表（L0/L1/L2/L5 组合快照）
CREATE TABLE IF NOT EXISTS `aw_persona_version` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `digital_human_id` BIGINT UNSIGNED NOT NULL COMMENT '角色ID',
  `version_no` INT UNSIGNED NOT NULL COMMENT '版本号(同角色内递增)',
  `l0_meta_rules` MEDIUMTEXT NOT NULL COMMENT 'L0 元规则',
  `l1_human_core` MEDIUMTEXT NOT NULL COMMENT 'L1 拟人化引擎',
  `l2_persona_core` MEDIUMTEXT NOT NULL COMMENT 'L2 人格内核',
  `l5_output_protocol` MEDIUMTEXT NOT NULL COMMENT 'L5 输出协议',
  `remark` VARCHAR(255) NULL COMMENT '版本说明',
  `is_active` TINYINT NOT NULL DEFAULT 0 COMMENT '是否当前生效版本: 1是 0否',
  `created_by` VARCHAR(64) NULL COMMENT '创建人',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_aw_persona_version_unique` (`digital_human_id`, `version_no`),
  KEY `idx_aw_persona_version_active` (`digital_human_id`, `is_active`),
  CONSTRAINT `fk_aw_persona_version_digital_human_id`
    FOREIGN KEY (`digital_human_id`) REFERENCES `aw_digital_human` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='数字人人设版本';

-- 补充外键：角色当前生效版本 -> 人设版本
ALTER TABLE `aw_digital_human`
  ADD CONSTRAINT `fk_aw_digital_human_current_persona_version_id`
  FOREIGN KEY (`current_persona_version_id`) REFERENCES `aw_persona_version` (`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;

-- 4. 会话表（用户与数字人的会话）
CREATE TABLE IF NOT EXISTS `aw_session` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `session_no` VARCHAR(64) NOT NULL COMMENT '业务会话号(唯一)',
  `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
  `digital_human_id` BIGINT UNSIGNED NOT NULL COMMENT '数字人ID',
  `persona_version_id` BIGINT UNSIGNED NOT NULL COMMENT '会话绑定人设版本',
  `title` VARCHAR(128) NULL COMMENT '会话标题',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 1进行中 2结束 0删除',
  `last_message_at` DATETIME NULL COMMENT '最后一条消息时间',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_aw_session_session_no` (`session_no`),
  KEY `idx_aw_session_user_dh` (`user_id`, `digital_human_id`),
  KEY `idx_aw_session_last_message_at` (`last_message_at`),
  CONSTRAINT `fk_aw_session_user_id`
    FOREIGN KEY (`user_id`) REFERENCES `aw_user` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_aw_session_digital_human_id`
    FOREIGN KEY (`digital_human_id`) REFERENCES `aw_digital_human` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_aw_session_persona_version_id`
    FOREIGN KEY (`persona_version_id`) REFERENCES `aw_persona_version` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='会话主表';

-- 5. 消息表（会话消息流）
CREATE TABLE IF NOT EXISTS `aw_message` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `session_id` BIGINT UNSIGNED NOT NULL COMMENT '会话ID',
  `sender_type` TINYINT NOT NULL COMMENT '发送方: 1用户 2数字人 3系统',
  `sender_id` BIGINT UNSIGNED NULL COMMENT '发送方ID(用户或数字人)',
  `message_type` TINYINT NOT NULL DEFAULT 1 COMMENT '消息类型: 1文本 2图片 3语音 4指令',
  `content` MEDIUMTEXT NOT NULL COMMENT '消息内容',
  `meta_json` JSON NULL COMMENT '扩展字段(JSON)',
  `token_input` INT UNSIGNED NULL COMMENT '本次请求输入token',
  `token_output` INT UNSIGNED NULL COMMENT '本次回复输出token',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_aw_message_session_id` (`session_id`),
  KEY `idx_aw_message_sender_type` (`sender_type`),
  KEY `idx_aw_message_created_at` (`created_at`),
  CONSTRAINT `fk_aw_message_session_id`
    FOREIGN KEY (`session_id`) REFERENCES `aw_session` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='会话消息';

-- 6. 长期记忆表（L3 结构化存储）
CREATE TABLE IF NOT EXISTS `aw_memory` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
  `digital_human_id` BIGINT UNSIGNED NOT NULL COMMENT '数字人ID',
  `memory_type` TINYINT NOT NULL COMMENT '记忆类型: 1事实 2偏好 3关系 4时间线',
  `memory_key` VARCHAR(128) NOT NULL COMMENT '记忆键',
  `memory_value` TEXT NOT NULL COMMENT '记忆值',
  `weight` DECIMAL(5,2) NOT NULL DEFAULT 1.00 COMMENT '记忆权重',
  `source_session_id` BIGINT UNSIGNED NULL COMMENT '来源会话ID',
  `last_hit_at` DATETIME NULL COMMENT '最近命中时间',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_aw_memory_unique` (`user_id`, `digital_human_id`, `memory_key`),
  KEY `idx_aw_memory_type` (`memory_type`),
  KEY `idx_aw_memory_last_hit_at` (`last_hit_at`),
  CONSTRAINT `fk_aw_memory_user_id`
    FOREIGN KEY (`user_id`) REFERENCES `aw_user` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_aw_memory_digital_human_id`
    FOREIGN KEY (`digital_human_id`) REFERENCES `aw_digital_human` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_aw_memory_source_session_id`
    FOREIGN KEY (`source_session_id`) REFERENCES `aw_session` (`id`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='长期记忆';

-- 7. 情境快照表（L4 每轮上下文注入记录）
CREATE TABLE IF NOT EXISTS `aw_context_snapshot` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `session_id` BIGINT UNSIGNED NOT NULL COMMENT '会话ID',
  `message_id` BIGINT UNSIGNED NULL COMMENT '触发该快照的消息ID',
  `context_json` JSON NOT NULL COMMENT 'L4 情境JSON',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_aw_context_snapshot_session_id` (`session_id`),
  KEY `idx_aw_context_snapshot_message_id` (`message_id`),
  CONSTRAINT `fk_aw_context_snapshot_session_id`
    FOREIGN KEY (`session_id`) REFERENCES `aw_session` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_aw_context_snapshot_message_id`
    FOREIGN KEY (`message_id`) REFERENCES `aw_message` (`id`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='情境快照';

-- 8. 设备指令表（对应 L6 扩展）
CREATE TABLE IF NOT EXISTS `aw_device_command` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `session_id` BIGINT UNSIGNED NOT NULL COMMENT '会话ID',
  `message_id` BIGINT UNSIGNED NULL COMMENT '关联消息ID',
  `device_type` VARCHAR(64) NOT NULL COMMENT '设备类型',
  `command_name` VARCHAR(64) NOT NULL COMMENT '指令名',
  `command_payload` JSON NOT NULL COMMENT '指令参数',
  `execute_status` TINYINT NOT NULL DEFAULT 0 COMMENT '执行状态: 0待执行 1成功 2失败',
  `error_message` VARCHAR(255) NULL COMMENT '失败原因',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_aw_device_command_session_id` (`session_id`),
  KEY `idx_aw_device_command_status` (`execute_status`),
  CONSTRAINT `fk_aw_device_command_session_id`
    FOREIGN KEY (`session_id`) REFERENCES `aw_session` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_aw_device_command_message_id`
    FOREIGN KEY (`message_id`) REFERENCES `aw_message` (`id`)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='设备控制指令';

-- 9. 操作日志表（可选：审计与排错）
CREATE TABLE IF NOT EXISTS `aw_audit_log` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `trace_id` VARCHAR(64) NOT NULL COMMENT '请求链路ID',
  `session_id` BIGINT UNSIGNED NULL COMMENT '会话ID',
  `event_type` VARCHAR(64) NOT NULL COMMENT '事件类型',
  `event_detail` JSON NULL COMMENT '事件详情',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_aw_audit_log_trace_id` (`trace_id`),
  KEY `idx_aw_audit_log_session_id` (`session_id`),
  KEY `idx_aw_audit_log_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='审计日志';

