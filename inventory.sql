-- inventory_db_mysql.sql
-- Project: Retail Inventory & Order Management DB (MySQL 8.0+)
-- Author: Your Name
-- Description: Core schema with proper PKs, FKs, UNIQUE, and example 1-1, 1-M, M-M relationships.
-- Notes:
--   * Uses InnoDB and utf8mb4 for full FK support.
--   * CHECK constraints require MySQL 8.0.16+.
--   * This file contains only CREATE TABLE statements by design (per assignment).

/* =========================
   SESSION & DATABASE SETUP
   ========================= */
-- Adjust database name as needed
CREATE DATABASE IF NOT EXISTS retail_inventory
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
USE retail_inventory;

SET NAMES utf8mb4;
SET time_zone = '+00:00';

/* =========================
   LOOKUP TABLES
   ========================= */
CREATE TABLE roles (
  role_id     TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  role_name   VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE po_statuses (
  po_status_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  status_name  VARCHAR(30) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE so_statuses (
  so_status_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  status_name  VARCHAR(30) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE invoice_statuses (
  invoice_status_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  status_name       VARCHAR(30) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE payment_methods (
  payment_method_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  method_name       VARCHAR(30) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE location_types (
  location_type_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  type_name        VARCHAR(30) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE movement_reasons (
  movement_reason_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  reason_name        VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

/* =========================
   CORE ENTITIES
   ========================= */
CREATE TABLE users (
  user_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  role_id     TINYINT UNSIGNED NOT NULL,
  full_name   VARCHAR(100) NOT NULL,
  email       VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARBINARY(255) NOT NULL,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_users_role
    FOREIGN KEY (role_id) REFERENCES roles(role_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE suppliers (
  supplier_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  supplier_name VARCHAR(150) NOT NULL UNIQUE,
  contact_email VARCHAR(255) NULL,
  phone         VARCHAR(30) NULL,
  address_line1 VARCHAR(150) NULL,
  city          VARCHAR(80) NULL,
  country       VARCHAR(80) NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE customers (
  customer_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  customer_name VARCHAR(150) NOT NULL,
  email         VARCHAR(255) NULL,
  phone         VARCHAR(30) NULL,
  UNIQUE KEY uq_customers_email (email),
  UNIQUE KEY uq_customers_phone (phone)
) ENGINE=InnoDB;

CREATE TABLE categories (
  category_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  category_name VARCHAR(100) NOT NULL UNIQUE,
  parent_id     INT UNSIGNED NULL,
  CONSTRAINT fk_categories_parent
    FOREIGN KEY (parent_id) REFERENCES categories(category_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE products (
  product_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sku          VARCHAR(50) NOT NULL UNIQUE,
  product_name VARCHAR(150) NOT NULL,
  supplier_id  INT UNSIGNED NULL,
  unit_cost    DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  unit_price   DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  barcode      VARCHAR(64) NULL UNIQUE,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_products_supplier
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  CHECK (unit_cost >= 0),
  CHECK (unit_price >= 0)
) ENGINE=InnoDB;

-- M-M: products <-> categories
CREATE TABLE product_categories (
  product_id  INT UNSIGNED NOT NULL,
  category_id INT UNSIGNED NOT NULL,
  PRIMARY KEY (product_id, category_id),
  CONSTRAINT fk_pc_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  CONSTRAINT fk_pc_category
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE stock_locations (
  location_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  location_name    VARCHAR(120) NOT NULL UNIQUE,
  location_type_id TINYINT UNSIGNED NOT NULL,
  address_line1    VARCHAR(150) NULL,
  city             VARCHAR(80) NULL,
  country          VARCHAR(80) NULL,
  CONSTRAINT fk_locations_type
    FOREIGN KEY (location_type_id) REFERENCES location_types(location_type_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Current on-hand snapshot per product+location
CREATE TABLE stock_levels (
  product_id  INT UNSIGNED NOT NULL,
  location_id INT UNSIGNED NOT NULL,
  quantity    DECIMAL(18,3) NOT NULL DEFAULT 0.000,
  PRIMARY KEY (product_id, location_id),
  CONSTRAINT fk_stocklevels_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  CONSTRAINT fk_stocklevels_location
    FOREIGN KEY (location_id) REFERENCES stock_locations(location_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  CHECK (quantity >= 0)
) ENGINE=InnoDB;

-- Movement ledger for auditability (receipts, issues, transfers, adjustments)
CREATE TABLE inventory_movements (
  movement_id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id          INT UNSIGNED NOT NULL,
  from_location_id    INT UNSIGNED NULL,
  to_location_id      INT UNSIGNED NULL,
  quantity            DECIMAL(18,3) NOT NULL,
  movement_reason_id  TINYINT UNSIGNED NOT NULL,
  reference_type      VARCHAR(40) NULL,      -- e.g., 'PO', 'SO', 'ADJUSTMENT'
  reference_id        BIGINT UNSIGNED NULL,  -- e.g., purchase_orders.po_id or sales_orders.so_id
  created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by          INT UNSIGNED NULL,
  CONSTRAINT fk_im_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_im_from_location
    FOREIGN KEY (from_location_id) REFERENCES stock_locations(location_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  CONSTRAINT fk_im_to_location
    FOREIGN KEY (to_location_id) REFERENCES stock_locations(location_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  CONSTRAINT fk_im_reason
    FOREIGN KEY (movement_reason_id) REFERENCES movement_reasons(movement_reason_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_im_user
    FOREIGN KEY (created_by) REFERENCES users(user_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL,
  CHECK (quantity > 0),
  CHECK (
    -- For a transfer, both from and to are not null.
    -- For a receipt, from is null, to is not null.
    -- For an issue, to is null, from is not null.
    (from_location_id IS NULL AND to_location_id IS NOT NULL)
    OR (from_location_id IS NOT NULL AND to_location_id IS NULL)
    OR (from_location_id IS NOT NULL AND to_location_id IS NOT NULL)
  )
) ENGINE=InnoDB;

/* =========================
   PURCHASING
   ========================= */
CREATE TABLE purchase_orders (
  po_id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  supplier_id   INT UNSIGNED NOT NULL,
  ordered_by    INT UNSIGNED NOT NULL,
  po_status_id  TINYINT UNSIGNED NOT NULL,
  order_date    DATE NOT NULL,
  expected_date DATE NULL,
  notes         VARCHAR(500) NULL,
  CONSTRAINT fk_po_supplier
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_po_user
    FOREIGN KEY (ordered_by) REFERENCES users(user_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_po_status
    FOREIGN KEY (po_status_id) REFERENCES po_statuses(po_status_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE purchase_order_items (
  po_id       BIGINT UNSIGNED NOT NULL,
  line_no     SMALLINT UNSIGNED NOT NULL,
  product_id  INT UNSIGNED NOT NULL,
  quantity    DECIMAL(18,3) NOT NULL,
  unit_cost   DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (po_id, line_no),
  CONSTRAINT fk_poi_po
    FOREIGN KEY (po_id) REFERENCES purchase_orders(po_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  CONSTRAINT fk_poi_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CHECK (quantity > 0),
  CHECK (unit_cost >= 0)
) ENGINE=InnoDB;

/* =========================
   SALES
   ========================= */
CREATE TABLE sales_orders (
  so_id        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  customer_id  INT UNSIGNED NOT NULL,
  so_status_id TINYINT UNSIGNED NOT NULL,
  order_date   DATE NOT NULL,
  fulfilled_at TIMESTAMP NULL,
  notes        VARCHAR(500) NULL,
  CONSTRAINT fk_so_customer
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_so_status
    FOREIGN KEY (so_status_id) REFERENCES so_statuses(so_status_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE sales_order_items (
  so_id       BIGINT UNSIGNED NOT NULL,
  line_no     SMALLINT UNSIGNED NOT NULL,
  product_id  INT UNSIGNED NOT NULL,
  quantity    DECIMAL(18,3) NOT NULL,
  unit_price  DECIMAL(12,2) NOT NULL,
  discount_pct DECIMAL(5,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (so_id, line_no),
  CONSTRAINT fk_soi_so
    FOREIGN KEY (so_id) REFERENCES sales_orders(so_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  CONSTRAINT fk_soi_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CHECK (quantity > 0),
  CHECK (unit_price >= 0),
  CHECK (discount_pct >= 0 AND discount_pct <= 100)
) ENGINE=InnoDB;

-- 1-1 example: invoice <-> sales_order (invoice PK is also FK to sales_orders)
CREATE TABLE invoices (
  invoice_id         BIGINT UNSIGNED PRIMARY KEY, -- equals sales_orders.so_id
  invoice_number     VARCHAR(40) NOT NULL UNIQUE,
  issue_date         DATE NOT NULL,
  due_date           DATE NULL,
  invoice_status_id  TINYINT UNSIGNED NOT NULL,
  CONSTRAINT fk_invoice_so
    FOREIGN KEY (invoice_id) REFERENCES sales_orders(so_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE,
  CONSTRAINT fk_invoice_status
    FOREIGN KEY (invoice_status_id) REFERENCES invoice_statuses(invoice_status_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE payments (
  payment_id        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  invoice_id        BIGINT UNSIGNED NOT NULL,
  amount            DECIMAL(12,2) NOT NULL,
  payment_method_id TINYINT UNSIGNED NOT NULL,
  paid_at           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reference_code    VARCHAR(60) NULL,
  CONSTRAINT fk_pay_invoice
    FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CONSTRAINT fk_pay_method
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(payment_method_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,
  CHECK (amount > 0)
) ENGINE=InnoDB;

CREATE TABLE shipments (
  shipment_id  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  so_id        BIGINT UNSIGNED NOT NULL,
  carrier      VARCHAR(60) NULL,
  tracking_no  VARCHAR(80) NULL UNIQUE,
  ship_date    DATE NULL,
  delivered_at TIMESTAMP NULL,
  CONSTRAINT fk_ship_so
    FOREIGN KEY (so_id) REFERENCES sales_orders(so_id)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) ENGINE=InnoDB;

/* =========================
   AUDIT (OPTIONAL, SIMPLE)
   ========================= */
CREATE TABLE audit_logs (
  audit_id    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  entity_name VARCHAR(60) NOT NULL,   -- e.g., 'products', 'sales_orders'
  entity_id   BIGINT UNSIGNED NOT NULL,
  action      VARCHAR(20) NOT NULL,   -- e.g., 'INSERT','UPDATE','DELETE'
  changed_by  INT UNSIGNED NULL,
  changed_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  details     JSON NULL,
  CONSTRAINT fk_audit_user
    FOREIGN KEY (changed_by) REFERENCES users(user_id)
    ON UPDATE CASCADE
    ON DELETE SET NULL
) ENGINE=InnoDB;

/* =========================
   SANE DEFAULT DATA (OPTIONAL)
   ========================= */
INSERT INTO roles (role_name) VALUES ('Admin'), ('Manager'), ('Clerk');
INSERT INTO po_statuses (status_name) VALUES ('Draft'), ('Sent'), ('Received'), ('Closed'), ('Cancelled');
INSERT INTO so_statuses (status_name) VALUES ('Draft'), ('Confirmed'), ('Fulfilled'), ('Cancelled'), ('Returned');
INSERT INTO invoice_statuses (status_name) VALUES ('Open'), ('Paid'), ('Partially Paid'), ('Cancelled');
INSERT INTO payment_methods (method_name) VALUES ('Cash'), ('Card'), ('M-Pesa'), ('Bank Transfer');
INSERT INTO location_types (type_name) VALUES ('Warehouse'), ('Storefront'), ('Transit'), ('Supplier');
INSERT INTO movement_reasons (reason_name) VALUES ('Purchase Receipt'), ('Sales Issue'), ('Transfer'), ('Adjustment+'), ('Adjustment-');
