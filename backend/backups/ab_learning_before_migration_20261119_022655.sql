-- MySQL dump 10.13  Distrib 8.0.46, for Linux (x86_64)
--
-- Host: localhost    Database: ab_learning
-- ------------------------------------------------------
-- Server version	8.0.46

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `achievements`
--

DROP TABLE IF EXISTS `achievements`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `achievements` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `badge_id` int unsigned NOT NULL,
  `earned_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_achievement` (`user_id`,`badge_id`),
  KEY `badge_id` (`badge_id`),
  CONSTRAINT `achievements_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `achievements_ibfk_2` FOREIGN KEY (`badge_id`) REFERENCES `badges` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `achievements`
--

LOCK TABLES `achievements` WRITE;
/*!40000 ALTER TABLE `achievements` DISABLE KEYS */;
/*!40000 ALTER TABLE `achievements` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ai_conversations`
--

DROP TABLE IF EXISTS `ai_conversations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_conversations` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `course_id` bigint unsigned DEFAULT NULL,
  `lesson_id` bigint unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `course_id` (`course_id`),
  KEY `lesson_id` (`lesson_id`),
  CONSTRAINT `ai_conversations_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `ai_conversations_ibfk_2` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`),
  CONSTRAINT `ai_conversations_ibfk_3` FOREIGN KEY (`lesson_id`) REFERENCES `lessons` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ai_conversations`
--

LOCK TABLES `ai_conversations` WRITE;
/*!40000 ALTER TABLE `ai_conversations` DISABLE KEYS */;
/*!40000 ALTER TABLE `ai_conversations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `ai_messages`
--

DROP TABLE IF EXISTS `ai_messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_messages` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `conversation_id` bigint unsigned NOT NULL,
  `role` enum('user','assistant') NOT NULL,
  `content` text NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `conversation_id` (`conversation_id`),
  CONSTRAINT `ai_messages_ibfk_1` FOREIGN KEY (`conversation_id`) REFERENCES `ai_conversations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ai_messages`
--

LOCK TABLES `ai_messages` WRITE;
/*!40000 ALTER TABLE `ai_messages` DISABLE KEYS */;
/*!40000 ALTER TABLE `ai_messages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `audit_logs`
--

DROP TABLE IF EXISTS `audit_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `audit_logs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `actor_id` bigint unsigned DEFAULT NULL,
  `action` varchar(100) NOT NULL,
  `target_type` varchar(50) DEFAULT NULL,
  `target_id` bigint unsigned DEFAULT NULL,
  `metadata` json DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `actor_id` (`actor_id`),
  CONSTRAINT `audit_logs_ibfk_1` FOREIGN KEY (`actor_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `audit_logs`
--

LOCK TABLES `audit_logs` WRITE;
/*!40000 ALTER TABLE `audit_logs` DISABLE KEYS */;
/*!40000 ALTER TABLE `audit_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `badges`
--

DROP TABLE IF EXISTS `badges`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `badges` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `icon_url` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `badges`
--

LOCK TABLES `badges` WRITE;
/*!40000 ALTER TABLE `badges` DISABLE KEYS */;
/*!40000 ALTER TABLE `badges` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `career_path_skills`
--

DROP TABLE IF EXISTS `career_path_skills`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `career_path_skills` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `career_path_id` bigint unsigned NOT NULL,
  `skill_id` int unsigned NOT NULL,
  `required_level` enum('beginner','intermediate','advanced') DEFAULT 'intermediate',
  PRIMARY KEY (`id`),
  KEY `career_path_id` (`career_path_id`),
  KEY `skill_id` (`skill_id`),
  CONSTRAINT `career_path_skills_ibfk_1` FOREIGN KEY (`career_path_id`) REFERENCES `career_paths` (`id`) ON DELETE CASCADE,
  CONSTRAINT `career_path_skills_ibfk_2` FOREIGN KEY (`skill_id`) REFERENCES `skills` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `career_path_skills`
--

LOCK TABLES `career_path_skills` WRITE;
/*!40000 ALTER TABLE `career_path_skills` DISABLE KEYS */;
/*!40000 ALTER TABLE `career_path_skills` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `career_paths`
--

DROP TABLE IF EXISTS `career_paths`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `career_paths` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `title` varchar(200) NOT NULL,
  `description` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `career_paths`
--

LOCK TABLES `career_paths` WRITE;
/*!40000 ALTER TABLE `career_paths` DISABLE KEYS */;
/*!40000 ALTER TABLE `career_paths` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `categories`
--

DROP TABLE IF EXISTS `categories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `categories` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `name_th` varchar(100) NOT NULL,
  `name_en` varchar(100) NOT NULL,
  `slug` varchar(120) NOT NULL,
  `icon` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `slug` (`slug`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `categories`
--

LOCK TABLES `categories` WRITE;
/*!40000 ALTER TABLE `categories` DISABLE KEYS */;
INSERT INTO `categories` VALUES (1,'การเขียนโปรแกรม','Programming','programming',NULL),(2,'ปัญญาประดิษฐ์','AI','ai',NULL),(3,'ข้อมูล','Data','data',NULL),(4,'การตลาด','Marketing','marketing',NULL),(5,'ธุรกิจ','Business','business',NULL);
/*!40000 ALTER TABLE `categories` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `certificates`
--

DROP TABLE IF EXISTS `certificates`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `certificates` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `enrollment_id` bigint unsigned NOT NULL,
  `certificate_code` varchar(40) NOT NULL,
  `pdf_url` varchar(500) DEFAULT NULL,
  `issued_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `enrollment_id` (`enrollment_id`),
  UNIQUE KEY `certificate_code` (`certificate_code`),
  CONSTRAINT `certificates_ibfk_1` FOREIGN KEY (`enrollment_id`) REFERENCES `enrollments` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `certificates`
--

LOCK TABLES `certificates` WRITE;
/*!40000 ALTER TABLE `certificates` DISABLE KEYS */;
/*!40000 ALTER TABLE `certificates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `comments`
--

DROP TABLE IF EXISTS `comments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `comments` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `post_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  `content` text NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `post_id` (`post_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `comments_ibfk_1` FOREIGN KEY (`post_id`) REFERENCES `community_posts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `comments_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `comments`
--

LOCK TABLES `comments` WRITE;
/*!40000 ALTER TABLE `comments` DISABLE KEYS */;
/*!40000 ALTER TABLE `comments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `communities`
--

DROP TABLE IF EXISTS `communities`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `communities` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(150) NOT NULL,
  `description` text,
  `cover_url` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `communities`
--

LOCK TABLES `communities` WRITE;
/*!40000 ALTER TABLE `communities` DISABLE KEYS */;
/*!40000 ALTER TABLE `communities` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `community_posts`
--

DROP TABLE IF EXISTS `community_posts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `community_posts` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `community_id` bigint unsigned DEFAULT NULL,
  `user_id` bigint unsigned NOT NULL,
  `title` varchar(200) DEFAULT NULL,
  `content` text NOT NULL,
  `image_url` varchar(500) DEFAULT NULL,
  `course_tag_id` bigint unsigned DEFAULT NULL,
  `like_count` int unsigned DEFAULT '0',
  `comment_count` int unsigned DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `community_id` (`community_id`),
  KEY `user_id` (`user_id`),
  KEY `course_tag_id` (`course_tag_id`),
  CONSTRAINT `community_posts_ibfk_1` FOREIGN KEY (`community_id`) REFERENCES `communities` (`id`),
  CONSTRAINT `community_posts_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `community_posts_ibfk_3` FOREIGN KEY (`course_tag_id`) REFERENCES `courses` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `community_posts`
--

LOCK TABLES `community_posts` WRITE;
/*!40000 ALTER TABLE `community_posts` DISABLE KEYS */;
/*!40000 ALTER TABLE `community_posts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `coupons`
--

DROP TABLE IF EXISTS `coupons`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `coupons` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `code` varchar(40) NOT NULL,
  `discount_type` enum('percent','fixed') NOT NULL,
  `discount_value` decimal(10,2) NOT NULL,
  `course_id` bigint unsigned DEFAULT NULL,
  `max_uses` int unsigned DEFAULT NULL,
  `used_count` int unsigned DEFAULT '0',
  `expires_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `code` (`code`),
  KEY `course_id` (`course_id`),
  CONSTRAINT `coupons_ibfk_1` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `coupons`
--

LOCK TABLES `coupons` WRITE;
/*!40000 ALTER TABLE `coupons` DISABLE KEYS */;
/*!40000 ALTER TABLE `coupons` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `course_sections`
--

DROP TABLE IF EXISTS `course_sections`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `course_sections` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `course_id` bigint unsigned NOT NULL,
  `title` varchar(200) NOT NULL,
  `sort_order` int unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `course_id` (`course_id`),
  CONSTRAINT `course_sections_ibfk_1` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `course_sections`
--

LOCK TABLES `course_sections` WRITE;
/*!40000 ALTER TABLE `course_sections` DISABLE KEYS */;
INSERT INTO `course_sections` VALUES (1,1,'Introduction',1),(2,1,'REST API',2);
/*!40000 ALTER TABLE `course_sections` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `courses`
--

DROP TABLE IF EXISTS `courses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `courses` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `instructor_id` bigint unsigned NOT NULL,
  `category_id` int unsigned NOT NULL,
  `title` varchar(200) NOT NULL,
  `slug` varchar(220) NOT NULL,
  `description` text,
  `level` enum('beginner','intermediate','advanced') DEFAULT 'beginner',
  `language` varchar(10) DEFAULT 'th',
  `thumbnail_url` varchar(500) DEFAULT NULL,
  `price` decimal(10,2) NOT NULL DEFAULT '0.00',
  `discount_price` decimal(10,2) DEFAULT NULL,
  `duration_minutes` int unsigned DEFAULT '0',
  `rating_avg` decimal(3,2) DEFAULT '0.00',
  `rating_count` int unsigned DEFAULT '0',
  `student_count` int unsigned DEFAULT '0',
  `status` enum('draft','pending_review','published','rejected','archived') NOT NULL DEFAULT 'draft',
  `rejected_reason` varchar(500) DEFAULT NULL,
  `published_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `slug` (`slug`),
  KEY `instructor_id` (`instructor_id`),
  KEY `idx_courses_status` (`status`),
  KEY `idx_courses_category` (`category_id`),
  CONSTRAINT `courses_ibfk_1` FOREIGN KEY (`instructor_id`) REFERENCES `instructors` (`id`),
  CONSTRAINT `courses_ibfk_2` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `courses`
--

LOCK TABLES `courses` WRITE;
/*!40000 ALTER TABLE `courses` DISABLE KEYS */;
INSERT INTO `courses` VALUES (1,1,1,'Go Backend Professional','go-backend-professional','เรียนรู้การออกแบบ REST API ด้วย Go เชื่อมต่อ MySQL และ deploy สู่ production จริง','intermediate','th',NULL,4990.00,2990.00,1110,4.90,2140,8421,'published',NULL,'2026-11-18 15:31:48','2026-11-18 15:31:48','2026-11-18 15:31:48'),(2,2,2,'AI for Business','ai-for-business','ประยุกต์ใช้ AI เพื่อสร้างมูลค่าทางธุรกิจ ตั้งแต่ automation ถึง decision support','beginner','th',NULL,1990.00,NULL,480,4.90,890,3120,'published',NULL,'2026-11-18 15:31:48','2026-11-18 15:31:48','2026-11-18 15:31:48'),(3,2,2,'Prompt Engineering','prompt-engineering','เทคนิคการเขียน prompt อย่างมืออาชีพสำหรับงานจริง','beginner','th',NULL,1490.00,NULL,240,0.00,0,0,'pending_review',NULL,NULL,'2026-11-18 15:31:48','2026-11-18 15:31:48');
/*!40000 ALTER TABLE `courses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `creator_payouts`
--

DROP TABLE IF EXISTS `creator_payouts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `creator_payouts` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `instructor_id` bigint unsigned NOT NULL,
  `period_start` date NOT NULL,
  `period_end` date NOT NULL,
  `gross_amount` decimal(12,2) NOT NULL,
  `platform_fee` decimal(12,2) NOT NULL,
  `net_amount` decimal(12,2) NOT NULL,
  `status` enum('pending','paid') DEFAULT 'pending',
  `paid_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `instructor_id` (`instructor_id`),
  CONSTRAINT `creator_payouts_ibfk_1` FOREIGN KEY (`instructor_id`) REFERENCES `instructors` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `creator_payouts`
--

LOCK TABLES `creator_payouts` WRITE;
/*!40000 ALTER TABLE `creator_payouts` DISABLE KEYS */;
/*!40000 ALTER TABLE `creator_payouts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `employers`
--

DROP TABLE IF EXISTS `employers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `employers` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `company_name` varchar(200) NOT NULL,
  `logo_url` varchar(500) DEFAULT NULL,
  `website` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`),
  CONSTRAINT `employers_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `employers`
--

LOCK TABLES `employers` WRITE;
/*!40000 ALTER TABLE `employers` DISABLE KEYS */;
INSERT INTO `employers` VALUES (1,6,'TechCorp Thailand',NULL,'https://techcorp.example.com');
/*!40000 ALTER TABLE `employers` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `enrollments`
--

DROP TABLE IF EXISTS `enrollments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `enrollments` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `course_id` bigint unsigned NOT NULL,
  `progress_pct` decimal(5,2) NOT NULL DEFAULT '0.00',
  `status` enum('in_progress','completed','dropped') NOT NULL DEFAULT 'in_progress',
  `last_lesson_id` bigint unsigned DEFAULT NULL,
  `enrolled_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `completed_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_enrollment` (`user_id`,`course_id`),
  KEY `course_id` (`course_id`),
  KEY `last_lesson_id` (`last_lesson_id`),
  CONSTRAINT `enrollments_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `enrollments_ibfk_2` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`),
  CONSTRAINT `enrollments_ibfk_3` FOREIGN KEY (`last_lesson_id`) REFERENCES `lessons` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `enrollments`
--

LOCK TABLES `enrollments` WRITE;
/*!40000 ALTER TABLE `enrollments` DISABLE KEYS */;
INSERT INTO `enrollments` VALUES (1,3,1,68.00,'in_progress',NULL,'2026-11-18 15:31:48',NULL);
/*!40000 ALTER TABLE `enrollments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `instructors`
--

DROP TABLE IF EXISTS `instructors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `instructors` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `headline` varchar(200) DEFAULT NULL,
  `expertise` json DEFAULT NULL,
  `rating_avg` decimal(3,2) DEFAULT '0.00',
  `total_students` int unsigned DEFAULT '0',
  `verified_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`),
  CONSTRAINT `instructors_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `instructors`
--

LOCK TABLES `instructors` WRITE;
/*!40000 ALTER TABLE `instructors` DISABLE KEYS */;
INSERT INTO `instructors` VALUES (1,1,'Backend & Cloud Architecture','[\"Go\", \"MySQL\", \"Docker\", \"Kubernetes\"]',4.90,8421,'2026-11-18 15:31:48'),(2,2,'Applied AI for Business','[\"AI\", \"Data\", \"Prompt Engineering\"]',4.90,3120,'2026-11-18 15:31:48');
/*!40000 ALTER TABLE `instructors` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `job_applications`
--

DROP TABLE IF EXISTS `job_applications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `job_applications` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `job_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  `portfolio_id` bigint unsigned NOT NULL,
  `match_score` decimal(5,2) DEFAULT NULL,
  `status` enum('submitted','reviewed','shortlisted','rejected','hired') DEFAULT 'submitted',
  `applied_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_application` (`job_id`,`user_id`),
  KEY `user_id` (`user_id`),
  KEY `portfolio_id` (`portfolio_id`),
  CONSTRAINT `job_applications_ibfk_1` FOREIGN KEY (`job_id`) REFERENCES `jobs` (`id`) ON DELETE CASCADE,
  CONSTRAINT `job_applications_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `job_applications_ibfk_3` FOREIGN KEY (`portfolio_id`) REFERENCES `portfolios` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `job_applications`
--

LOCK TABLES `job_applications` WRITE;
/*!40000 ALTER TABLE `job_applications` DISABLE KEYS */;
INSERT INTO `job_applications` VALUES (1,1,3,1,92.00,'submitted','2026-11-18 15:31:48');
/*!40000 ALTER TABLE `job_applications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `jobs`
--

DROP TABLE IF EXISTS `jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `jobs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `employer_id` bigint unsigned NOT NULL,
  `title` varchar(200) NOT NULL,
  `description` text,
  `requirements` text,
  `skill_tags` json DEFAULT NULL,
  `location` varchar(150) DEFAULT NULL,
  `is_remote` tinyint(1) DEFAULT '0',
  `salary_min` decimal(10,2) DEFAULT NULL,
  `salary_max` decimal(10,2) DEFAULT NULL,
  `employment_type` enum('full_time','part_time','contract','internship') DEFAULT 'full_time',
  `status` enum('open','closed') DEFAULT 'open',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `employer_id` (`employer_id`),
  CONSTRAINT `jobs_ibfk_1` FOREIGN KEY (`employer_id`) REFERENCES `employers` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `jobs`
--

LOCK TABLES `jobs` WRITE;
/*!40000 ALTER TABLE `jobs` DISABLE KEYS */;
INSERT INTO `jobs` VALUES (1,1,'Backend Developer','ร่วมทีมพัฒนา Backend สำหรับแพลตฟอร์ม e-commerce ที่มีผู้ใช้กว่า 2 ล้านคน','Go, PostgreSQL, Docker','[\"Go\", \"PostgreSQL\", \"Docker\"]','Bangkok',1,45000.00,65000.00,'full_time','open','2026-11-18 15:31:48'),(2,1,'Cloud Engineer','ดูแลระบบ Cloud infrastructure และ CI/CD pipeline','AWS, Kubernetes','[\"AWS\", \"Kubernetes\"]','Bangkok',0,55000.00,80000.00,'full_time','open','2026-11-18 15:31:48');
/*!40000 ALTER TABLE `jobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `learning_path_assignments`
--

DROP TABLE IF EXISTS `learning_path_assignments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `learning_path_assignments` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `learning_path_id` bigint unsigned NOT NULL,
  `organization_user_id` bigint unsigned NOT NULL,
  `progress_pct` decimal(5,2) DEFAULT '0.00',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_assignment` (`learning_path_id`,`organization_user_id`),
  KEY `organization_user_id` (`organization_user_id`),
  CONSTRAINT `learning_path_assignments_ibfk_1` FOREIGN KEY (`learning_path_id`) REFERENCES `learning_paths` (`id`) ON DELETE CASCADE,
  CONSTRAINT `learning_path_assignments_ibfk_2` FOREIGN KEY (`organization_user_id`) REFERENCES `organization_users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `learning_path_assignments`
--

LOCK TABLES `learning_path_assignments` WRITE;
/*!40000 ALTER TABLE `learning_path_assignments` DISABLE KEYS */;
/*!40000 ALTER TABLE `learning_path_assignments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `learning_path_courses`
--

DROP TABLE IF EXISTS `learning_path_courses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `learning_path_courses` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `learning_path_id` bigint unsigned NOT NULL,
  `course_id` bigint unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `learning_path_id` (`learning_path_id`),
  KEY `course_id` (`course_id`),
  CONSTRAINT `learning_path_courses_ibfk_1` FOREIGN KEY (`learning_path_id`) REFERENCES `learning_paths` (`id`) ON DELETE CASCADE,
  CONSTRAINT `learning_path_courses_ibfk_2` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `learning_path_courses`
--

LOCK TABLES `learning_path_courses` WRITE;
/*!40000 ALTER TABLE `learning_path_courses` DISABLE KEYS */;
/*!40000 ALTER TABLE `learning_path_courses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `learning_paths`
--

DROP TABLE IF EXISTS `learning_paths`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `learning_paths` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `organization_id` bigint unsigned NOT NULL,
  `name` varchar(200) NOT NULL,
  `goal` varchar(300) DEFAULT NULL,
  `deadline` date DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `organization_id` (`organization_id`),
  CONSTRAINT `learning_paths_ibfk_1` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `learning_paths`
--

LOCK TABLES `learning_paths` WRITE;
/*!40000 ALTER TABLE `learning_paths` DISABLE KEYS */;
/*!40000 ALTER TABLE `learning_paths` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lesson_progress`
--

DROP TABLE IF EXISTS `lesson_progress`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `lesson_progress` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `enrollment_id` bigint unsigned NOT NULL,
  `lesson_id` bigint unsigned NOT NULL,
  `status` enum('not_started','in_progress','completed') NOT NULL DEFAULT 'not_started',
  `watched_seconds` int unsigned DEFAULT '0',
  `completed_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_progress` (`enrollment_id`,`lesson_id`),
  KEY `lesson_id` (`lesson_id`),
  CONSTRAINT `lesson_progress_ibfk_1` FOREIGN KEY (`enrollment_id`) REFERENCES `enrollments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `lesson_progress_ibfk_2` FOREIGN KEY (`lesson_id`) REFERENCES `lessons` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lesson_progress`
--

LOCK TABLES `lesson_progress` WRITE;
/*!40000 ALTER TABLE `lesson_progress` DISABLE KEYS */;
/*!40000 ALTER TABLE `lesson_progress` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lessons`
--

DROP TABLE IF EXISTS `lessons`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `lessons` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `section_id` bigint unsigned NOT NULL,
  `title` varchar(200) NOT NULL,
  `type` enum('video','article','quiz','project') NOT NULL DEFAULT 'video',
  `video_url` varchar(500) DEFAULT NULL,
  `duration_seconds` int unsigned DEFAULT '0',
  `resource_urls` json DEFAULT NULL,
  `sort_order` int unsigned NOT NULL DEFAULT '0',
  `is_preview` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `section_id` (`section_id`),
  CONSTRAINT `lessons_ibfk_1` FOREIGN KEY (`section_id`) REFERENCES `course_sections` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lessons`
--

LOCK TABLES `lessons` WRITE;
/*!40000 ALTER TABLE `lessons` DISABLE KEYS */;
INSERT INTO `lessons` VALUES (1,1,'Welcome & Setup','video',NULL,480,NULL,1,1),(2,2,'REST API with Go','video',NULL,1475,NULL,1,0),(3,2,'JWT Authentication','video',NULL,1082,NULL,2,0);
/*!40000 ALTER TABLE `lessons` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `likes`
--

DROP TABLE IF EXISTS `likes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `likes` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `post_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_like` (`post_id`,`user_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `likes_ibfk_1` FOREIGN KEY (`post_id`) REFERENCES `community_posts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `likes_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `likes`
--

LOCK TABLES `likes` WRITE;
/*!40000 ALTER TABLE `likes` DISABLE KEYS */;
/*!40000 ALTER TABLE `likes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `live_attendees`
--

DROP TABLE IF EXISTS `live_attendees`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `live_attendees` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `live_session_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  `joined_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_attendee` (`live_session_id`,`user_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `live_attendees_ibfk_1` FOREIGN KEY (`live_session_id`) REFERENCES `live_sessions` (`id`) ON DELETE CASCADE,
  CONSTRAINT `live_attendees_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `live_attendees`
--

LOCK TABLES `live_attendees` WRITE;
/*!40000 ALTER TABLE `live_attendees` DISABLE KEYS */;
/*!40000 ALTER TABLE `live_attendees` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `live_questions`
--

DROP TABLE IF EXISTS `live_questions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `live_questions` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `live_session_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  `question` text NOT NULL,
  `upvotes` int unsigned DEFAULT '0',
  `answered` tinyint(1) DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `live_session_id` (`live_session_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `live_questions_ibfk_1` FOREIGN KEY (`live_session_id`) REFERENCES `live_sessions` (`id`) ON DELETE CASCADE,
  CONSTRAINT `live_questions_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `live_questions`
--

LOCK TABLES `live_questions` WRITE;
/*!40000 ALTER TABLE `live_questions` DISABLE KEYS */;
/*!40000 ALTER TABLE `live_questions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `live_sessions`
--

DROP TABLE IF EXISTS `live_sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `live_sessions` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `course_id` bigint unsigned DEFAULT NULL,
  `instructor_id` bigint unsigned NOT NULL,
  `title` varchar(200) NOT NULL,
  `scheduled_at` datetime NOT NULL,
  `duration_minutes` int unsigned DEFAULT '60',
  `stream_url` varchar(500) DEFAULT NULL,
  `replay_url` varchar(500) DEFAULT NULL,
  `price` decimal(10,2) DEFAULT '0.00',
  `status` enum('upcoming','live','ended','cancelled') NOT NULL DEFAULT 'upcoming',
  PRIMARY KEY (`id`),
  KEY `course_id` (`course_id`),
  KEY `instructor_id` (`instructor_id`),
  CONSTRAINT `live_sessions_ibfk_1` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`),
  CONSTRAINT `live_sessions_ibfk_2` FOREIGN KEY (`instructor_id`) REFERENCES `instructors` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `live_sessions`
--

LOCK TABLES `live_sessions` WRITE;
/*!40000 ALTER TABLE `live_sessions` DISABLE KEYS */;
INSERT INTO `live_sessions` VALUES (1,2,2,'AI for Business — Live Q&A','2026-11-18 17:31:48',60,NULL,NULL,0.00,'upcoming');
/*!40000 ALTER TABLE `live_sessions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notifications` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `type` varchar(50) NOT NULL,
  `title` varchar(200) NOT NULL,
  `body` varchar(500) DEFAULT NULL,
  `is_read` tinyint(1) DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_notif_user_read` (`user_id`,`is_read`),
  CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notifications`
--

LOCK TABLES `notifications` WRITE;
/*!40000 ALTER TABLE `notifications` DISABLE KEYS */;
/*!40000 ALTER TABLE `notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `order_items`
--

DROP TABLE IF EXISTS `order_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `order_items` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `order_id` bigint unsigned NOT NULL,
  `course_id` bigint unsigned NOT NULL,
  `price` decimal(10,2) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `order_id` (`order_id`),
  KEY `course_id` (`course_id`),
  CONSTRAINT `order_items_ibfk_1` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE,
  CONSTRAINT `order_items_ibfk_2` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `order_items`
--

LOCK TABLES `order_items` WRITE;
/*!40000 ALTER TABLE `order_items` DISABLE KEYS */;
INSERT INTO `order_items` VALUES (1,1,1,2990.00);
/*!40000 ALTER TABLE `order_items` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `orders`
--

DROP TABLE IF EXISTS `orders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `orders` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `order_code` varchar(30) NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  `coupon_id` bigint unsigned DEFAULT NULL,
  `subtotal` decimal(10,2) NOT NULL,
  `discount_total` decimal(10,2) NOT NULL DEFAULT '0.00',
  `grand_total` decimal(10,2) NOT NULL,
  `status` enum('pending','paid','failed','refunded','cancelled') NOT NULL DEFAULT 'pending',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `order_code` (`order_code`),
  KEY `user_id` (`user_id`),
  KEY `coupon_id` (`coupon_id`),
  KEY `idx_orders_status` (`status`),
  CONSTRAINT `orders_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `orders_ibfk_2` FOREIGN KEY (`coupon_id`) REFERENCES `coupons` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `orders`
--

LOCK TABLES `orders` WRITE;
/*!40000 ALTER TABLE `orders` DISABLE KEYS */;
INSERT INTO `orders` VALUES (1,'ORD-10001',3,NULL,4990.00,2000.00,2990.00,'paid','2026-11-18 15:31:48');
/*!40000 ALTER TABLE `orders` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `organization_users`
--

DROP TABLE IF EXISTS `organization_users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `organization_users` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `organization_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  `department` varchar(150) DEFAULT NULL,
  `role_in_org` enum('admin','manager','employee') DEFAULT 'employee',
  `status` enum('active','inactive') DEFAULT 'active',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_org_user` (`organization_id`,`user_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `organization_users_ibfk_1` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `organization_users_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `organization_users`
--

LOCK TABLES `organization_users` WRITE;
/*!40000 ALTER TABLE `organization_users` DISABLE KEYS */;
INSERT INTO `organization_users` VALUES (1,1,4,'Human Resources','admin','active'),(2,1,3,'Engineering','employee','active'),(3,1,5,'Learning & Development','manager','active');
/*!40000 ALTER TABLE `organization_users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `organizations`
--

DROP TABLE IF EXISTS `organizations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `organizations` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(200) NOT NULL,
  `logo_url` varchar(500) DEFAULT NULL,
  `employee_count` int unsigned DEFAULT '0',
  `training_budget` decimal(12,2) DEFAULT '0.00',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `organizations`
--

LOCK TABLES `organizations` WRITE;
/*!40000 ALTER TABLE `organizations` DISABLE KEYS */;
INSERT INTO `organizations` VALUES (1,'ABC Technology',NULL,500,500000.00);
/*!40000 ALTER TABLE `organizations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `otp_verifications`
--

DROP TABLE IF EXISTS `otp_verifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `otp_verifications` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `code` varchar(6) NOT NULL,
  `purpose` enum('register','login','reset_password') NOT NULL,
  `expires_at` datetime NOT NULL,
  `consumed_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `otp_verifications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `otp_verifications`
--

LOCK TABLES `otp_verifications` WRITE;
/*!40000 ALTER TABLE `otp_verifications` DISABLE KEYS */;
/*!40000 ALTER TABLE `otp_verifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `password_resets`
--

DROP TABLE IF EXISTS `password_resets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `password_resets` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `token` varchar(255) NOT NULL,
  `expires_at` datetime NOT NULL,
  `used_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `token` (`token`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `password_resets_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `password_resets`
--

LOCK TABLES `password_resets` WRITE;
/*!40000 ALTER TABLE `password_resets` DISABLE KEYS */;
/*!40000 ALTER TABLE `password_resets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `payments`
--

DROP TABLE IF EXISTS `payments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `payments` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `order_id` bigint unsigned NOT NULL,
  `method` enum('promptpay','card','stripe','wallet') NOT NULL,
  `provider_ref` varchar(150) DEFAULT NULL,
  `amount` decimal(10,2) NOT NULL,
  `status` enum('pending','success','failed') NOT NULL DEFAULT 'pending',
  `paid_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `order_id` (`order_id`),
  CONSTRAINT `payments_ibfk_1` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `payments`
--

LOCK TABLES `payments` WRITE;
/*!40000 ALTER TABLE `payments` DISABLE KEYS */;
INSERT INTO `payments` VALUES (1,1,'promptpay','PPAY-TEST-001',2990.00,'success','2026-11-18 15:31:48');
/*!40000 ALTER TABLE `payments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `portfolio_projects`
--

DROP TABLE IF EXISTS `portfolio_projects`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `portfolio_projects` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `portfolio_id` bigint unsigned NOT NULL,
  `title` varchar(200) NOT NULL,
  `description` text,
  `skill_tags` json DEFAULT NULL,
  `project_url` varchar(500) DEFAULT NULL,
  `image_url` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `portfolio_id` (`portfolio_id`),
  CONSTRAINT `portfolio_projects_ibfk_1` FOREIGN KEY (`portfolio_id`) REFERENCES `portfolios` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `portfolio_projects`
--

LOCK TABLES `portfolio_projects` WRITE;
/*!40000 ALTER TABLE `portfolio_projects` DISABLE KEYS */;
/*!40000 ALTER TABLE `portfolio_projects` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `portfolios`
--

DROP TABLE IF EXISTS `portfolios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `portfolios` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `headline` varchar(200) DEFAULT NULL,
  `summary` text,
  `resume_url` varchar(500) DEFAULT NULL,
  `social_links` json DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`),
  CONSTRAINT `portfolios_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `portfolios`
--

LOCK TABLES `portfolios` WRITE;
/*!40000 ALTER TABLE `portfolios` DISABLE KEYS */;
INSERT INTO `portfolios` VALUES (1,3,'Backend Developer','Go, SQL, Docker enthusiast building real projects.',NULL,NULL);
/*!40000 ALTER TABLE `portfolios` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `profiles`
--

DROP TABLE IF EXISTS `profiles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `profiles` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `first_name` varchar(100) DEFAULT NULL,
  `last_name` varchar(100) DEFAULT NULL,
  `avatar_url` varchar(500) DEFAULT NULL,
  `bio` text,
  `title` varchar(150) DEFAULT NULL,
  `location` varchar(150) DEFAULT NULL,
  `date_of_birth` date DEFAULT NULL,
  `gender` enum('male','female','other','undisclosed') DEFAULT 'undisclosed',
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`),
  CONSTRAINT `profiles_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `profiles`
--

LOCK TABLES `profiles` WRITE;
/*!40000 ALTER TABLE `profiles` DISABLE KEYS */;
INSERT INTO `profiles` VALUES (1,1,'Krit','Anantasin',NULL,NULL,'Backend & Cloud Instructor',NULL,NULL,'undisclosed'),(2,2,'Bank','Thanakit',NULL,NULL,'AI & Data Instructor',NULL,NULL,'undisclosed'),(3,3,'Anan','Suksawat',NULL,NULL,'Backend Developer','Bangkok',NULL,'undisclosed'),(4,4,'Siriwan','Kittipong',NULL,NULL,'HR Director',NULL,NULL,'undisclosed'),(5,5,'Nattaya','Wongchai',NULL,NULL,'Learning Manager',NULL,NULL,'undisclosed'),(6,6,'Pakorn','Srisawat',NULL,NULL,'Talent Acquisition Manager',NULL,NULL,'undisclosed'),(7,7,'System','Administrator',NULL,NULL,'Super Admin',NULL,NULL,'undisclosed');
/*!40000 ALTER TABLE `profiles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `quiz_attempts`
--

DROP TABLE IF EXISTS `quiz_attempts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `quiz_attempts` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `quiz_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  `answers` json NOT NULL,
  `score_pct` decimal(5,2) NOT NULL,
  `passed` tinyint(1) NOT NULL,
  `skill_breakdown` json DEFAULT NULL,
  `attempted_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `quiz_id` (`quiz_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `quiz_attempts_ibfk_1` FOREIGN KEY (`quiz_id`) REFERENCES `quizzes` (`id`),
  CONSTRAINT `quiz_attempts_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `quiz_attempts`
--

LOCK TABLES `quiz_attempts` WRITE;
/*!40000 ALTER TABLE `quiz_attempts` DISABLE KEYS */;
/*!40000 ALTER TABLE `quiz_attempts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `quiz_questions`
--

DROP TABLE IF EXISTS `quiz_questions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `quiz_questions` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `quiz_id` bigint unsigned NOT NULL,
  `question` text NOT NULL,
  `choices` json NOT NULL,
  `correct_choice` varchar(10) NOT NULL,
  `skill_tag` varchar(100) DEFAULT NULL,
  `sort_order` int unsigned DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `quiz_id` (`quiz_id`),
  CONSTRAINT `quiz_questions_ibfk_1` FOREIGN KEY (`quiz_id`) REFERENCES `quizzes` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `quiz_questions`
--

LOCK TABLES `quiz_questions` WRITE;
/*!40000 ALTER TABLE `quiz_questions` DISABLE KEYS */;
/*!40000 ALTER TABLE `quiz_questions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `quizzes`
--

DROP TABLE IF EXISTS `quizzes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `quizzes` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `course_id` bigint unsigned NOT NULL,
  `lesson_id` bigint unsigned DEFAULT NULL,
  `title` varchar(200) NOT NULL,
  `pass_score_pct` decimal(5,2) NOT NULL DEFAULT '70.00',
  PRIMARY KEY (`id`),
  KEY `course_id` (`course_id`),
  KEY `lesson_id` (`lesson_id`),
  CONSTRAINT `quizzes_ibfk_1` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`) ON DELETE CASCADE,
  CONSTRAINT `quizzes_ibfk_2` FOREIGN KEY (`lesson_id`) REFERENCES `lessons` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `quizzes`
--

LOCK TABLES `quizzes` WRITE;
/*!40000 ALTER TABLE `quizzes` DISABLE KEYS */;
/*!40000 ALTER TABLE `quizzes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `refunds`
--

DROP TABLE IF EXISTS `refunds`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `refunds` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `payment_id` bigint unsigned NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `reason` varchar(500) DEFAULT NULL,
  `status` enum('requested','processed','rejected') NOT NULL DEFAULT 'requested',
  `processed_by` bigint unsigned DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `payment_id` (`payment_id`),
  KEY `processed_by` (`processed_by`),
  CONSTRAINT `refunds_ibfk_1` FOREIGN KEY (`payment_id`) REFERENCES `payments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `refunds_ibfk_2` FOREIGN KEY (`processed_by`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `refunds`
--

LOCK TABLES `refunds` WRITE;
/*!40000 ALTER TABLE `refunds` DISABLE KEYS */;
/*!40000 ALTER TABLE `refunds` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reports`
--

DROP TABLE IF EXISTS `reports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reports` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `reporter_id` bigint unsigned NOT NULL,
  `target_type` enum('course','post','comment','user') NOT NULL,
  `target_id` bigint unsigned NOT NULL,
  `reason` varchar(500) NOT NULL,
  `status` enum('open','reviewed','dismissed') DEFAULT 'open',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `reporter_id` (`reporter_id`),
  CONSTRAINT `reports_ibfk_1` FOREIGN KEY (`reporter_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reports`
--

LOCK TABLES `reports` WRITE;
/*!40000 ALTER TABLE `reports` DISABLE KEYS */;
/*!40000 ALTER TABLE `reports` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reviews`
--

DROP TABLE IF EXISTS `reviews`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reviews` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `course_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  `rating` tinyint unsigned NOT NULL,
  `comment` text,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_review` (`course_id`,`user_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `reviews_ibfk_1` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`) ON DELETE CASCADE,
  CONSTRAINT `reviews_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reviews`
--

LOCK TABLES `reviews` WRITE;
/*!40000 ALTER TABLE `reviews` DISABLE KEYS */;
/*!40000 ALTER TABLE `reviews` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `roles`
--

DROP TABLE IF EXISTS `roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `roles` (
  `id` tinyint unsigned NOT NULL AUTO_INCREMENT,
  `code` varchar(30) NOT NULL,
  `name_th` varchar(100) NOT NULL,
  `name_en` varchar(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `code` (`code`)
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `roles`
--

LOCK TABLES `roles` WRITE;
/*!40000 ALTER TABLE `roles` DISABLE KEYS */;
INSERT INTO `roles` VALUES (1,'LEARNER','ผู้เรียน','Learner'),(2,'INSTRUCTOR','ผู้สอน','Instructor'),(3,'CORP_ADMIN','ผู้ดูแลองค์กร','Corporate Admin'),(4,'CORP_MANAGER','ผู้จัดการองค์กร','Corporate Manager'),(5,'EMPLOYER','นายจ้าง','Employer'),(6,'ADMIN','ผู้ดูแลระบบ','Super Admin');
/*!40000 ALTER TABLE `roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `schema_migrations`
--

DROP TABLE IF EXISTS `schema_migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `schema_migrations` (
  `name` varchar(190) NOT NULL,
  `applied_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `schema_migrations`
--

LOCK TABLES `schema_migrations` WRITE;
/*!40000 ALTER TABLE `schema_migrations` DISABLE KEYS */;
/*!40000 ALTER TABLE `schema_migrations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `skill_assessments`
--

DROP TABLE IF EXISTS `skill_assessments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `skill_assessments` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `title` varchar(200) NOT NULL,
  `category` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `skill_assessments`
--

LOCK TABLES `skill_assessments` WRITE;
/*!40000 ALTER TABLE `skill_assessments` DISABLE KEYS */;
/*!40000 ALTER TABLE `skill_assessments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `skill_questions`
--

DROP TABLE IF EXISTS `skill_questions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `skill_questions` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `assessment_id` bigint unsigned NOT NULL,
  `skill_id` int unsigned NOT NULL,
  `question` text NOT NULL,
  `choices` json NOT NULL,
  `correct_choice` varchar(10) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `assessment_id` (`assessment_id`),
  KEY `skill_id` (`skill_id`),
  CONSTRAINT `skill_questions_ibfk_1` FOREIGN KEY (`assessment_id`) REFERENCES `skill_assessments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `skill_questions_ibfk_2` FOREIGN KEY (`skill_id`) REFERENCES `skills` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `skill_questions`
--

LOCK TABLES `skill_questions` WRITE;
/*!40000 ALTER TABLE `skill_questions` DISABLE KEYS */;
/*!40000 ALTER TABLE `skill_questions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `skill_results`
--

DROP TABLE IF EXISTS `skill_results`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `skill_results` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `assessment_id` bigint unsigned NOT NULL,
  `overall_score` decimal(5,2) NOT NULL,
  `breakdown` json NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `assessment_id` (`assessment_id`),
  CONSTRAINT `skill_results_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `skill_results_ibfk_2` FOREIGN KEY (`assessment_id`) REFERENCES `skill_assessments` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `skill_results`
--

LOCK TABLES `skill_results` WRITE;
/*!40000 ALTER TABLE `skill_results` DISABLE KEYS */;
/*!40000 ALTER TABLE `skill_results` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `skills`
--

DROP TABLE IF EXISTS `skills`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `skills` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `category` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `skills`
--

LOCK TABLES `skills` WRITE;
/*!40000 ALTER TABLE `skills` DISABLE KEYS */;
/*!40000 ALTER TABLE `skills` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `subscriptions`
--

DROP TABLE IF EXISTS `subscriptions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `subscriptions` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `plan` varchar(50) NOT NULL,
  `status` enum('active','cancelled','expired') DEFAULT 'active',
  `started_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `expires_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `subscriptions_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `subscriptions`
--

LOCK TABLES `subscriptions` WRITE;
/*!40000 ALTER TABLE `subscriptions` DISABLE KEYS */;
/*!40000 ALTER TABLE `subscriptions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_points`
--

DROP TABLE IF EXISTS `user_points`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_points` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `level` int unsigned DEFAULT '1',
  `xp` bigint unsigned DEFAULT '0',
  `streak_days` int unsigned DEFAULT '0',
  `last_activity_date` date DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`),
  CONSTRAINT `user_points_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_points`
--

LOCK TABLES `user_points` WRITE;
/*!40000 ALTER TABLE `user_points` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_points` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_preferences`
--

DROP TABLE IF EXISTS `user_preferences`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_preferences` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `interests` json DEFAULT NULL,
  `level` enum('beginner','intermediate','advanced') DEFAULT NULL,
  `goal` enum('get_job','upskill','career_change','freelance','business') DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`),
  CONSTRAINT `user_preferences_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_preferences`
--

LOCK TABLES `user_preferences` WRITE;
/*!40000 ALTER TABLE `user_preferences` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_preferences` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `role_id` tinyint unsigned NOT NULL,
  `email` varchar(190) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `password_hash` varchar(255) NOT NULL,
  `status` enum('active','suspended','deactivated') NOT NULL DEFAULT 'active',
  `email_verified_at` datetime DEFAULT NULL,
  `last_login_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `phone` (`phone`),
  KEY `idx_users_role` (`role_id`),
  CONSTRAINT `users_ibfk_1` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,2,'krit@ablearning.com',NULL,'pbkdf2$sha256$210000$QWJsZWFybmluZ1NlZWRWMQ$w5jVCWaPBG4+crkXeoGXmdyigAdxvyBxD2rzz37jP1M','active',NULL,NULL,'2026-11-18 15:31:48','2026-11-18 15:31:48'),(2,2,'bank@ablearning.com',NULL,'pbkdf2$sha256$210000$QWJsZWFybmluZ1NlZWRWMQ$w5jVCWaPBG4+crkXeoGXmdyigAdxvyBxD2rzz37jP1M','active',NULL,NULL,'2026-11-18 15:31:48','2026-11-18 15:31:48'),(3,1,'learner@ablearning.com',NULL,'pbkdf2$sha256$210000$QWJsZWFybmluZ1NlZWRWMQ$w5jVCWaPBG4+crkXeoGXmdyigAdxvyBxD2rzz37jP1M','active',NULL,NULL,'2026-11-18 15:31:48','2026-11-18 15:31:48'),(4,3,'corp@ablearning.com',NULL,'pbkdf2$sha256$210000$QWJsZWFybmluZ1NlZWRWMQ$w5jVCWaPBG4+crkXeoGXmdyigAdxvyBxD2rzz37jP1M','active',NULL,NULL,'2026-11-18 15:31:48','2026-11-18 15:31:48'),(5,4,'manager@ablearning.com',NULL,'pbkdf2$sha256$210000$QWJsZWFybmluZ1NlZWRWMQ$w5jVCWaPBG4+crkXeoGXmdyigAdxvyBxD2rzz37jP1M','active',NULL,NULL,'2026-11-18 15:31:48','2026-11-18 15:31:48'),(6,5,'employer@ablearning.com',NULL,'pbkdf2$sha256$210000$QWJsZWFybmluZ1NlZWRWMQ$w5jVCWaPBG4+crkXeoGXmdyigAdxvyBxD2rzz37jP1M','active',NULL,NULL,'2026-11-18 15:31:48','2026-11-18 15:31:48'),(7,6,'admin@ablearning.com',NULL,'pbkdf2$sha256$210000$QWJsZWFybmluZ1NlZWRWMQ$w5jVCWaPBG4+crkXeoGXmdyigAdxvyBxD2rzz37jP1M','active',NULL,NULL,'2026-11-18 15:31:48','2026-11-18 15:31:48');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `wallet_transactions`
--

DROP TABLE IF EXISTS `wallet_transactions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `wallet_transactions` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `wallet_id` bigint unsigned NOT NULL,
  `type` enum('topup','withdraw','purchase','refund','reward') NOT NULL,
  `amount` decimal(12,2) NOT NULL,
  `balance_after` decimal(12,2) NOT NULL,
  `reference` varchar(150) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `wallet_id` (`wallet_id`),
  CONSTRAINT `wallet_transactions_ibfk_1` FOREIGN KEY (`wallet_id`) REFERENCES `wallets` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `wallet_transactions`
--

LOCK TABLES `wallet_transactions` WRITE;
/*!40000 ALTER TABLE `wallet_transactions` DISABLE KEYS */;
/*!40000 ALTER TABLE `wallet_transactions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `wallets`
--

DROP TABLE IF EXISTS `wallets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `wallets` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `coin_balance` bigint unsigned DEFAULT '0',
  `cash_balance` decimal(12,2) DEFAULT '0.00',
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`),
  CONSTRAINT `wallets_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `wallets`
--

LOCK TABLES `wallets` WRITE;
/*!40000 ALTER TABLE `wallets` DISABLE KEYS */;
INSERT INTO `wallets` VALUES (1,3,2450,850.00);
/*!40000 ALTER TABLE `wallets` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-11-18 19:26:56
