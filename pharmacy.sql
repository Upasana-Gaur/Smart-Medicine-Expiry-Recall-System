-- ENHANCED MEDICINE EXPIRY & RECALL SYSTEM
-- PostgreSQL Schema with Additional Features

-- Drop existing tables
DROP TABLE IF EXISTS purchase_orders CASCADE;
DROP TABLE IF EXISTS supplier_ratings CASCADE;
DROP TABLE IF EXISTS prescriptions CASCADE;
DROP TABLE IF EXISTS medicine_interactions CASCADE;
DROP TABLE IF EXISTS inventory_movements CASCADE;
DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS predicted_demand CASCADE;
DROP TABLE IF EXISTS alerts CASCADE;
DROP TABLE IF EXISTS recalls CASCADE;
DROP TABLE IF EXISTS sales CASCADE;
DROP TABLE IF EXISTS batches CASCADE;
DROP TABLE IF EXISTS medicines CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Users table with enhanced fields
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    role VARCHAR(20) CHECK (role IN ('pharmacist', 'manager', 'admin')) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Suppliers table with rating system
CREATE TABLE suppliers (
    supplier_id SERIAL PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL,
    contact_person VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(50),
    country VARCHAR(50),
    rating DECIMAL(3,2) CHECK (rating >= 0 AND rating <= 5),
    total_orders INTEGER DEFAULT 0,
    on_time_delivery_rate DECIMAL(5,2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Medicines table with enhanced information
CREATE TABLE medicines (
    medicine_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    generic_name VARCHAR(100),
    composition TEXT,
    manufacturer VARCHAR(100),
    dosage_form VARCHAR(50),
    strength VARCHAR(50),
    description TEXT,
    barcode VARCHAR(100) UNIQUE,
    category VARCHAR(50),
    storage_conditions TEXT,
    side_effects TEXT,
    requires_prescription BOOLEAN DEFAULT FALSE,
    minimum_stock_level INTEGER DEFAULT 10,
    reorder_point INTEGER DEFAULT 20,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Medicine interactions table
CREATE TABLE medicine_interactions (
    interaction_id SERIAL PRIMARY KEY,
    medicine_id_1 INTEGER REFERENCES medicines(medicine_id) ON DELETE CASCADE,
    medicine_id_2 INTEGER REFERENCES medicines(medicine_id) ON DELETE CASCADE,
    interaction_type VARCHAR(20) CHECK (interaction_type IN ('minor', 'moderate', 'severe')),
    description TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (medicine_id_1 < medicine_id_2)
);

-- Batches table with enhanced tracking
CREATE TABLE batches (
    batch_id SERIAL PRIMARY KEY,
    medicine_id INTEGER REFERENCES medicines(medicine_id) ON DELETE CASCADE,
    supplier_id INTEGER REFERENCES suppliers(supplier_id) ON DELETE SET NULL,
    batch_number VARCHAR(50) NOT NULL,
    expiry_date DATE NOT NULL,
    manufacture_date DATE,
    quantity INTEGER NOT NULL CHECK (quantity >= 0),
    cost_price DECIMAL(10,2),
    selling_price DECIMAL(10,2),
    mrp DECIMAL(10,2),
    barcode VARCHAR(100),
    storage_location VARCHAR(50),
    is_recalled BOOLEAN DEFAULT FALSE,
    is_expired BOOLEAN DEFAULT FALSE,
    ocr_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(medicine_id, batch_number)
);

-- Prescriptions table
CREATE TABLE prescriptions (
    prescription_id SERIAL PRIMARY KEY,
    prescription_number VARCHAR(50) UNIQUE NOT NULL,
    patient_name VARCHAR(100) NOT NULL,
    patient_phone VARCHAR(20),
    doctor_name VARCHAR(100) NOT NULL,
    doctor_license VARCHAR(50),
    issue_date DATE NOT NULL,
    expiry_date DATE,
    prescription_image_path TEXT,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'fulfilled', 'expired')),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sales table with prescription linking
CREATE TABLE sales (
    sale_id SERIAL PRIMARY KEY,
    batch_id INTEGER REFERENCES batches(batch_id) ON DELETE RESTRICT,
    prescription_id INTEGER REFERENCES prescriptions(prescription_id) ON DELETE SET NULL,
    quantity_sold INTEGER NOT NULL CHECK (quantity_sold > 0),
    sale_price DECIMAL(10,2) NOT NULL,
    discount_percentage DECIMAL(5,2) DEFAULT 0,
    total_amount DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(20) CHECK (payment_method IN ('cash', 'card', 'upi', 'insurance')),
    customer_name VARCHAR(100),
    customer_phone VARCHAR(20),
    customer_info TEXT,
    sold_by INTEGER REFERENCES users(user_id),
    sale_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Recalls table
CREATE TABLE recalls (
    recall_id SERIAL PRIMARY KEY,
    batch_id INTEGER REFERENCES batches(batch_id) ON DELETE CASCADE,
    recall_reason TEXT NOT NULL,
    recall_date DATE NOT NULL,
    announced_by VARCHAR(100),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'resolved', 'cancelled')),
    severity VARCHAR(20) CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    affected_quantity INTEGER,
    returned_quantity INTEGER DEFAULT 0,
    instructions TEXT,
    created_by INTEGER REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Alerts table with enhanced categorization
CREATE TABLE alerts (
    alert_id SERIAL PRIMARY KEY,
    batch_id INTEGER REFERENCES batches(batch_id) ON DELETE CASCADE,
    alert_type VARCHAR(20) CHECK (alert_type IN ('expiry', 'recall', 'low_stock', 'out_of_stock', 'reorder')) NOT NULL,
    alert_message TEXT NOT NULL,
    severity VARCHAR(10) CHECK (severity IN ('low', 'medium', 'high', 'critical')) DEFAULT 'medium',
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_by INTEGER REFERENCES users(user_id),
    acknowledged_at TIMESTAMP,
    action_taken TEXT
);

-- Predicted demand table with ML confidence
CREATE TABLE predicted_demand (
    prediction_id SERIAL PRIMARY KEY,
    medicine_id INTEGER REFERENCES medicines(medicine_id) ON DELETE CASCADE,
    predicted_date DATE NOT NULL,
    predicted_quantity INTEGER NOT NULL,
    confidence_level DECIMAL(3,2) CHECK (confidence_level >= 0 AND confidence_level <= 1),
    model_used VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Purchase orders table
CREATE TABLE purchase_orders (
    order_id SERIAL PRIMARY KEY,
    supplier_id INTEGER REFERENCES suppliers(supplier_id) ON DELETE SET NULL,
    medicine_id INTEGER REFERENCES medicines(medicine_id) ON DELETE CASCADE,
    order_number VARCHAR(50) UNIQUE NOT NULL,
    quantity_ordered INTEGER NOT NULL,
    expected_price DECIMAL(10,2),
    order_date DATE NOT NULL,
    expected_delivery_date DATE,
    actual_delivery_date DATE,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'shipped', 'delivered', 'cancelled')),
    created_by INTEGER REFERENCES users(user_id),
    auto_generated BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Supplier ratings table
CREATE TABLE supplier_ratings (
    rating_id SERIAL PRIMARY KEY,
    supplier_id INTEGER REFERENCES suppliers(supplier_id) ON DELETE CASCADE,
    order_id INTEGER REFERENCES purchase_orders(order_id) ON DELETE CASCADE,
    quality_rating INTEGER CHECK (quality_rating >= 1 AND quality_rating <= 5),
    delivery_rating INTEGER CHECK (delivery_rating >= 1 AND delivery_rating <= 5),
    communication_rating INTEGER CHECK (communication_rating >= 1 AND communication_rating <= 5),
    overall_rating DECIMAL(3,2),
    comments TEXT,
    rated_by INTEGER REFERENCES users(user_id),
    rated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Inventory movements table for tracking
CREATE TABLE inventory_movements (
    movement_id SERIAL PRIMARY KEY,
    batch_id INTEGER REFERENCES batches(batch_id) ON DELETE CASCADE,
    movement_type VARCHAR(20) CHECK (movement_type IN ('purchase', 'sale', 'return', 'adjustment', 'disposal')) NOT NULL,
    quantity INTEGER NOT NULL,
    reference_id INTEGER,
    reason TEXT,
    moved_by INTEGER REFERENCES users(user_id),
    movement_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Audit log table
CREATE TABLE audit_log (
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    record_id INTEGER NOT NULL,
    action VARCHAR(10) CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values JSONB,
    new_values JSONB,
    changed_by INTEGER REFERENCES users(user_id),
    ip_address VARCHAR(45),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===================================
-- FUNCTIONS AND STORED PROCEDURES
-- ===================================

-- Function to add batch with OCR verification
CREATE OR REPLACE FUNCTION add_batch(
    p_medicine_id INTEGER,
    p_supplier_id INTEGER,
    p_batch_number VARCHAR,
    p_expiry_date DATE,
    p_manufacture_date DATE,
    p_quantity INTEGER,
    p_cost_price DECIMAL,
    p_selling_price DECIMAL,
    p_barcode VARCHAR,
    p_ocr_verified BOOLEAN DEFAULT FALSE
) RETURNS INTEGER AS $$
DECLARE
    new_batch_id INTEGER;
    medicine_name VARCHAR;
BEGIN
    -- Insert batch
    INSERT INTO batches (
        medicine_id, supplier_id, batch_number, expiry_date, 
        manufacture_date, quantity, cost_price, selling_price, barcode, ocr_verified
    ) VALUES (
        p_medicine_id, p_supplier_id, p_batch_number, p_expiry_date,
        p_manufacture_date, p_quantity, p_cost_price, p_selling_price, p_barcode, p_ocr_verified
    ) RETURNING batch_id INTO new_batch_id;
    
    -- Record inventory movement
    INSERT INTO inventory_movements (batch_id, movement_type, quantity, moved_by, reason)
    VALUES (new_batch_id, 'purchase', p_quantity, 1, 'New batch received');
    
    -- Get medicine name for alerts
    SELECT name INTO medicine_name FROM medicines WHERE medicine_id = p_medicine_id;
    
    -- Generate expiry alerts
    IF p_expiry_date <= CURRENT_DATE + INTERVAL '7 days' THEN
        INSERT INTO alerts (batch_id, alert_type, alert_message, severity)
        VALUES (new_batch_id, 'expiry', 
                medicine_name || ' (Batch: ' || p_batch_number || ') expires in ' || (p_expiry_date - CURRENT_DATE) || ' days', 
                'critical');
    ELSIF p_expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN
        INSERT INTO alerts (batch_id, alert_type, alert_message, severity)
        VALUES (new_batch_id, 'expiry', 
                medicine_name || ' (Batch: ' || p_batch_number || ') expires within 30 days', 
                'high');
    ELSIF p_expiry_date <= CURRENT_DATE + INTERVAL '90 days' THEN
        INSERT INTO alerts (batch_id, alert_type, alert_message, severity)
        VALUES (new_batch_id, 'expiry', 
                medicine_name || ' (Batch: ' || p_batch_number || ') expires within 90 days', 
                'medium');
    END IF;
    
    RETURN new_batch_id;
END;
$$ LANGUAGE plpgsql;

-- Enhanced sale recording with prescription verification
CREATE OR REPLACE FUNCTION record_sale(
    p_batch_id INTEGER,
    p_quantity_sold INTEGER,
    p_sale_price DECIMAL,
    p_prescription_id INTEGER DEFAULT NULL,
    p_customer_name VARCHAR DEFAULT NULL,
    p_customer_phone VARCHAR DEFAULT NULL,
    p_payment_method VARCHAR DEFAULT 'cash',
    p_sold_by INTEGER DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    available_quantity INTEGER;
    new_sale_id INTEGER;
    medicine_info RECORD;
    current_stock INTEGER;
    reorder_point INTEGER;
BEGIN
    -- Get batch and medicine info
    SELECT b.quantity, m.name, m.requires_prescription, m.reorder_point, m.medicine_id
    INTO medicine_info
    FROM batches b
    JOIN medicines m ON b.medicine_id = m.medicine_id
    WHERE b.batch_id = p_batch_id;
    
    -- Check if prescription required
    IF medicine_info.requires_prescription AND p_prescription_id IS NULL THEN
        RAISE EXCEPTION 'Prescription required for medicine: %', medicine_info.name;
    END IF;
    
    -- Check stock availability
    IF medicine_info.quantity < p_quantity_sold THEN
        RAISE EXCEPTION 'Insufficient stock. Available: %, Requested: %', 
                        medicine_info.quantity, p_quantity_sold;
    END IF;
    
    -- Record sale
    INSERT INTO sales (
        batch_id, prescription_id, quantity_sold, sale_price, 
        total_amount, customer_name, customer_phone, payment_method, sold_by
    ) VALUES (
        p_batch_id, p_prescription_id, p_quantity_sold, p_sale_price,
        p_quantity_sold * p_sale_price, p_customer_name, p_customer_phone, 
        p_payment_method, p_sold_by
    ) RETURNING sale_id INTO new_sale_id;
    
    -- Record inventory movement
    INSERT INTO inventory_movements (batch_id, movement_type, quantity, reference_id, moved_by)
    VALUES (p_batch_id, 'sale', -p_quantity_sold, new_sale_id, p_sold_by);
    
    -- Check if reorder needed
    current_stock := medicine_info.quantity - p_quantity_sold;
    reorder_point := medicine_info.reorder_point;
    
    IF current_stock <= reorder_point THEN
        INSERT INTO alerts (batch_id, alert_type, alert_message, severity)
        VALUES (p_batch_id, 'reorder', 
                'Stock below reorder point for ' || medicine_info.name || '. Current: ' || current_stock, 
                CASE WHEN current_stock = 0 THEN 'critical' 
                     WHEN current_stock <= reorder_point / 2 THEN 'high' 
                     ELSE 'medium' END);
        
        -- Auto-generate purchase order if stock critical
        IF current_stock <= reorder_point / 2 THEN
            PERFORM generate_auto_purchase_order(medicine_info.medicine_id);
        END IF;
    END IF;
    
    RETURN new_sale_id;
END;
$ LANGUAGE plpgsql;

-- Function to generate automatic purchase orders
CREATE OR REPLACE FUNCTION generate_auto_purchase_order(p_medicine_id INTEGER)
RETURNS INTEGER AS $
DECLARE
    new_order_id INTEGER;
    best_supplier_id INTEGER;
    predicted_qty INTEGER;
    medicine_name VARCHAR;
BEGIN
    -- Get best supplier based on rating
    SELECT supplier_id INTO best_supplier_id
    FROM suppliers
    WHERE is_active = TRUE
    ORDER BY rating DESC NULLS LAST, on_time_delivery_rate DESC NULLS LAST
    LIMIT 1;
    
    -- Get predicted demand or default quantity
    SELECT COALESCE(MAX(predicted_quantity), 100) INTO predicted_qty
    FROM predicted_demand
    WHERE medicine_id = p_medicine_id
    AND predicted_date >= CURRENT_DATE
    LIMIT 1;
    
    SELECT name INTO medicine_name FROM medicines WHERE medicine_id = p_medicine_id;
    
    -- Create purchase order
    INSERT INTO purchase_orders (
        supplier_id, medicine_id, order_number, quantity_ordered,
        order_date, expected_delivery_date, status, auto_generated
    ) VALUES (
        best_supplier_id, p_medicine_id, 
        'PO-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || p_medicine_id,
        predicted_qty, CURRENT_DATE, CURRENT_DATE + INTERVAL '7 days',
        'pending', TRUE
    ) RETURNING order_id INTO new_order_id;
    
    RETURN new_order_id;
END;
$ LANGUAGE plpgsql;

-- Function to add recall with comprehensive tracking
CREATE OR REPLACE FUNCTION add_recall(
    p_batch_id INTEGER,
    p_recall_reason TEXT,
    p_recall_date DATE,
    p_announced_by VARCHAR,
    p_severity VARCHAR,
    p_instructions TEXT,
    p_created_by INTEGER
) RETURNS INTEGER AS $
DECLARE
    new_recall_id INTEGER;
    batch_info RECORD;
BEGIN
    SELECT b.batch_number, b.quantity, m.name as medicine_name 
    INTO batch_info
    FROM batches b
    JOIN medicines m ON b.medicine_id = m.medicine_id
    WHERE b.batch_id = p_batch_id;
    
    -- Create recall record
    INSERT INTO recalls (
        batch_id, recall_reason, recall_date, announced_by, 
        severity, affected_quantity, instructions, created_by
    ) VALUES (
        p_batch_id, p_recall_reason, p_recall_date, p_announced_by,
        p_severity, batch_info.quantity, p_instructions, p_created_by
    ) RETURNING recall_id INTO new_recall_id;
    
    -- Create high-priority alert
    INSERT INTO alerts (batch_id, alert_type, alert_message, severity)
    VALUES (p_batch_id, 'recall', 
            'URGENT RECALL: ' || batch_info.medicine_name || ' (Batch: ' || 
            batch_info.batch_number || ') - ' || p_recall_reason, 
            'critical');
    
    -- Mark batch as recalled
    UPDATE batches SET is_recalled = TRUE WHERE batch_id = p_batch_id;
    
    -- Record inventory movement
    INSERT INTO inventory_movements (batch_id, movement_type, quantity, reason, moved_by)
    VALUES (p_batch_id, 'disposal', -batch_info.quantity, 'Recalled: ' || p_recall_reason, p_created_by);
    
    RETURN new_recall_id;
END;
$ LANGUAGE plpgsql;

-- Function to rate supplier
CREATE OR REPLACE FUNCTION rate_supplier(
    p_supplier_id INTEGER,
    p_order_id INTEGER,
    p_quality INTEGER,
    p_delivery INTEGER,
    p_communication INTEGER,
    p_comments TEXT,
    p_rated_by INTEGER
) RETURNS void AS $
DECLARE
    overall DECIMAL(3,2);
    avg_rating DECIMAL(3,2);
BEGIN
    -- Calculate overall rating
    overall := (p_quality + p_delivery + p_communication) / 3.0;
    
    -- Insert rating
    INSERT INTO supplier_ratings (
        supplier_id, order_id, quality_rating, delivery_rating,
        communication_rating, overall_rating, comments, rated_by
    ) VALUES (
        p_supplier_id, p_order_id, p_quality, p_delivery,
        p_communication, overall, p_comments, p_rated_by
    );
    
    -- Update supplier average rating
    SELECT AVG(overall_rating) INTO avg_rating
    FROM supplier_ratings
    WHERE supplier_id = p_supplier_id;
    
    UPDATE suppliers 
    SET rating = avg_rating,
        total_orders = total_orders + 1
    WHERE supplier_id = p_supplier_id;
END;
$ LANGUAGE plpgsql;

-- Function to check medicine interactions
CREATE OR REPLACE FUNCTION check_medicine_interaction(
    p_medicine_ids INTEGER[]
) RETURNS TABLE (
    medicine1_name VARCHAR,
    medicine2_name VARCHAR,
    interaction_type VARCHAR,
    description TEXT
) AS $
BEGIN
    RETURN QUERY
    SELECT 
        m1.name as medicine1_name,
        m2.name as medicine2_name,
        mi.interaction_type,
        mi.description
    FROM medicine_interactions mi
    JOIN medicines m1 ON mi.medicine_id_1 = m1.medicine_id
    JOIN medicines m2 ON mi.medicine_id_2 = m2.medicine_id
    WHERE mi.medicine_id_1 = ANY(p_medicine_ids)
    AND mi.medicine_id_2 = ANY(p_medicine_ids);
END;
$ LANGUAGE plpgsql;

-- Function to get near expiry batches
CREATE OR REPLACE FUNCTION get_near_expiry_batches(days_threshold INTEGER DEFAULT 30)
RETURNS TABLE (
    batch_id INTEGER,
    batch_number VARCHAR,
    medicine_name VARCHAR,
    expiry_date DATE,
    days_until_expiry INTEGER,
    quantity INTEGER,
    selling_price DECIMAL
) AS $
BEGIN
    RETURN QUERY
    SELECT 
        b.batch_id,
        b.batch_number,
        m.name as medicine_name,
        b.expiry_date,
        (b.expiry_date - CURRENT_DATE) as days_until_expiry,
        b.quantity,
        b.selling_price
    FROM batches b
    JOIN medicines m ON b.medicine_id = m.medicine_id
    WHERE b.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + (days_threshold || ' days')::INTERVAL
    AND b.quantity > 0
    AND b.is_recalled = FALSE
    ORDER BY b.expiry_date ASC;
END;
$ LANGUAGE plpgsql;

-- ===================================
-- TRIGGERS
-- ===================================

-- Trigger to update batch quantity after sale
CREATE OR REPLACE FUNCTION update_batch_quantity()
RETURNS TRIGGER AS $
BEGIN
    UPDATE batches 
    SET quantity = quantity - NEW.quantity_sold 
    WHERE batch_id = NEW.batch_id;
    RETURN NEW;
END;
$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_stock_after_sale
    AFTER INSERT ON sales
    FOR EACH ROW
    EXECUTE FUNCTION update_batch_quantity();

-- Trigger to mark expired batches
CREATE OR REPLACE FUNCTION mark_expired_batches()
RETURNS void AS $
BEGIN
    UPDATE batches
    SET is_expired = TRUE
    WHERE expiry_date < CURRENT_DATE
    AND is_expired = FALSE;
END;
$ LANGUAGE plpgsql;

-- Trigger for audit logging
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, record_id, action, new_values, changed_by)
        VALUES (TG_TABLE_NAME, NEW.batch_id, 'INSERT', row_to_json(NEW), 1);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, record_id, action, old_values, new_values, changed_by)
        VALUES (TG_TABLE_NAME, NEW.batch_id, 'UPDATE', row_to_json(OLD), row_to_json(NEW), 1);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, record_id, action, old_values, changed_by)
        VALUES (TG_TABLE_NAME, OLD.batch_id, 'DELETE', row_to_json(OLD), 1);
        RETURN OLD;
    END IF;
END;
$ LANGUAGE plpgsql;

CREATE TRIGGER audit_batches_trigger
    AFTER INSERT OR UPDATE OR DELETE ON batches
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- Trigger to update supplier on-time delivery rate
CREATE OR REPLACE FUNCTION update_supplier_delivery_rate()
RETURNS TRIGGER AS $
DECLARE
    total INTEGER;
    on_time INTEGER;
    rate DECIMAL(5,2);
BEGIN
    IF NEW.status = 'delivered' AND NEW.actual_delivery_date IS NOT NULL THEN
        SELECT COUNT(*), COUNT(CASE WHEN actual_delivery_date <= expected_delivery_date THEN 1 END)
        INTO total, on_time
        FROM purchase_orders
        WHERE supplier_id = NEW.supplier_id
        AND status = 'delivered';
        
        rate := (on_time::DECIMAL / total::DECIMAL) * 100;
        
        UPDATE suppliers
        SET on_time_delivery_rate = rate
        WHERE supplier_id = NEW.supplier_id;
    END IF;
    
    RETURN NEW;
END;
$ LANGUAGE plpgsql;

CREATE TRIGGER update_delivery_rate_trigger
    AFTER UPDATE ON purchase_orders
    FOR EACH ROW
    WHEN (NEW.status = 'delivered')
    EXECUTE FUNCTION update_supplier_delivery_rate();

-- ===================================
-- VIEWS
-- ===================================

-- Enhanced pharmacist dashboard
CREATE VIEW pharmacist_dashboard AS
SELECT 
    m.medicine_id,
    m.name as medicine_name,
    m.generic_name,
    m.dosage_form,
    m.strength,
    m.requires_prescription,
    b.batch_id,
    b.batch_number,
    b.expiry_date,
    b.quantity as current_stock,
    b.selling_price,
    b.mrp,
    b.is_recalled,
    b.ocr_verified,
    s.supplier_name,
    CASE 
        WHEN b.is_recalled THEN 'RECALLED'
        WHEN b.expiry_date <= CURRENT_DATE THEN 'EXPIRED'
        WHEN b.expiry_date <= CURRENT_DATE + INTERVAL '7 days' THEN 'CRITICAL_EXPIRY'
        WHEN b.expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'NEAR_EXPIRY'
        WHEN b.quantity <= m.minimum_stock_level THEN 'LOW_STOCK'
        ELSE 'OK'
    END as stock_status,
    (b.expiry_date - CURRENT_DATE) as days_until_expiry
FROM medicines m
JOIN batches b ON m.medicine_id = b.medicine_id
LEFT JOIN suppliers s ON b.supplier_id = s.supplier_id
WHERE b.quantity > 0 AND m.is_active = TRUE
ORDER BY stock_status DESC, b.expiry_date ASC;

-- Manager analytics view
CREATE VIEW manager_analytics AS
SELECT 
    m.medicine_id,
    m.name as medicine_name,
    m.category,
    SUM(b.quantity) as total_stock,
    SUM(b.quantity * b.cost_price) as inventory_value,
    COUNT(DISTINCT b.batch_id) as active_batches,
    COUNT(CASE WHEN b.expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN 1 END) as near_expiry_batches,
    COUNT(CASE WHEN b.is_recalled THEN 1 END) as recalled_batches,
    COALESCE(SUM(s.quantity_sold), 0) as total_sold_30_days,
    COALESCE(SUM(s.total_amount), 0) as revenue_30_days,
    COALESCE(AVG(s.quantity_sold), 0) as avg_daily_sales,
    m.reorder_point,
    CASE 
        WHEN SUM(b.quantity) <= m.minimum_stock_level THEN 'REORDER_NOW'
        WHEN SUM(b.quantity) <= m.reorder_point THEN 'REORDER_SOON'
        ELSE 'OK'
    END as reorder_status
FROM medicines m
LEFT JOIN batches b ON m.medicine_id = b.medicine_id AND b.quantity > 0
LEFT JOIN sales s ON b.batch_id = s.batch_id AND s.sale_date >= CURRENT_DATE - INTERVAL '30 days'
WHERE m.is_active = TRUE
GROUP BY m.medicine_id, m.name, m.category, m.reorder_point, m.minimum_stock_level;

-- Active alerts view
CREATE VIEW active_alerts_view AS
SELECT 
    a.alert_id,
    a.alert_type,
    a.alert_message,
    a.severity,
    a.generated_at,
    m.name as medicine_name,
    b.batch_number,
    b.quantity as affected_quantity,
    a.is_acknowledged,
    u.full_name as acknowledged_by_name,
    a.acknowledged_at,
    a.action_taken
FROM alerts a
JOIN batches b ON a.batch_id = b.batch_id
JOIN medicines m ON b.medicine_id = m.medicine_id
LEFT JOIN users u ON a.acknowledged_by = u.user_id
WHERE a.is_acknowledged = FALSE
ORDER BY 
    CASE a.severity
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        ELSE 4
    END,
    a.generated_at DESC;

-- Sales summary view
CREATE VIEW sales_summary AS
SELECT 
    DATE(s.sale_date) as sale_date,
    m.name as medicine_name,
    m.category,
    SUM(s.quantity_sold) as total_quantity,
    SUM(s.total_amount) as total_revenue,
    AVG(s.sale_price) as avg_price,
    COUNT(DISTINCT s.sale_id) as transaction_count,
    u.full_name as sold_by
FROM sales s
JOIN batches b ON s.batch_id = b.batch_id
JOIN medicines m ON b.medicine_id = m.medicine_id
LEFT JOIN users u ON s.sold_by = u.user_id
GROUP BY DATE(s.sale_date), m.name, m.category, u.full_name
ORDER BY sale_date DESC;

-- Supplier performance view
CREATE VIEW supplier_performance AS
SELECT 
    s.supplier_id,
    s.supplier_name,
    s.rating as overall_rating,
    s.total_orders,
    s.on_time_delivery_rate,
    COUNT(po.order_id) as pending_orders,
    AVG(sr.quality_rating) as avg_quality,
    AVG(sr.delivery_rating) as avg_delivery,
    AVG(sr.communication_rating) as avg_communication,
    SUM(CASE WHEN po.status = 'delivered' THEN 1 ELSE 0 END) as completed_orders,
    SUM(CASE WHEN po.status = 'cancelled' THEN 1 ELSE 0 END) as cancelled_orders
FROM suppliers s
LEFT JOIN purchase_orders po ON s.supplier_id = po.supplier_id
LEFT JOIN supplier_ratings sr ON s.supplier_id = sr.supplier_id
WHERE s.is_active = TRUE
GROUP BY s.supplier_id, s.supplier_name, s.rating, s.total_orders, s.on_time_delivery_rate
ORDER BY s.rating DESC NULLS LAST;

-- ===================================
-- INDEXES FOR PERFORMANCE
-- ===================================

CREATE INDEX idx_batches_expiry ON batches(expiry_date) WHERE quantity > 0;
CREATE INDEX idx_batches_medicine ON batches(medicine_id);
CREATE INDEX idx_sales_date ON sales(sale_date);
CREATE INDEX idx_alerts_unacknowledged ON alerts(is_acknowledged) WHERE is_acknowledged = FALSE;
CREATE INDEX idx_medicines_name ON medicines(name);
CREATE INDEX idx_medicines_barcode ON medicines(barcode);
CREATE INDEX idx_predicted_demand_date ON predicted_demand(predicted_date, medicine_id);

-- ===================================
-- SAMPLE DATA
-- ===================================

-- Insert users
INSERT INTO users (username, password_hash, role, full_name, email, phone) VALUES
('admin', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5aqaJx.tQEDeC', 'admin', 'System Administrator', 'admin@pharmacy.com', '+91-9876543210'),
('manager1', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5aqaJx.tQEDeC', 'manager', 'Rajesh Kumar', 'rajesh@pharmacy.com', '+91-9876543211'),
('pharmacist1', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5aqaJx.tQEDeC', 'pharmacist', 'Priya Sharma', 'priya@pharmacy.com', '+91-9876543212'),
('pharmacist2', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5aqaJx.tQEDeC', 'pharmacist', 'Amit Singh', 'amit@pharmacy.com', '+91-9876543213');

-- Insert suppliers
INSERT INTO suppliers (supplier_name, contact_person, email, phone, city, country, rating) VALUES
('MedSupplier Inc', 'Suresh Patel', 'suresh@medsupplier.com', '+91-2234567890', 'Mumbai', 'India', 4.5),
('PharmaDistributors', 'Anjali Mehta', 'anjali@pharmadist.com', '+91-8022345678', 'Bangalore', 'India', 4.2),
('HealthCare Supplies', 'Vikram Reddy', 'vikram@healthcaresupplies.com', '+91-4433445566', 'Chennai', 'India', 4.7),
('Global Pharma Co', 'Neha Gupta', 'neha@globalpharma.com', '+91-1122334455', 'Delhi', 'India', 3.8);

-- Insert medicines
INSERT INTO medicines (name, generic_name, dosage_form, strength, manufacturer, barcode, category, requires_prescription, minimum_stock_level, reorder_point) VALUES
('Paracetamol', 'Acetaminophen', 'Tablet', '500mg', 'Cipla Ltd', '8901234567890', 'Analgesic', FALSE, 50, 100),
('Amoxicillin', 'Amoxicillin', 'Capsule', '250mg', 'Sun Pharma', '8901234567891', 'Antibiotic', TRUE, 30, 60),
('Ibuprofen', 'Ibuprofen', 'Tablet', '400mg', 'Dr. Reddy', '8901234567892', 'Anti-inflammatory', FALSE, 40, 80),
('Cetirizine', 'Cetirizine HCl', 'Tablet', '10mg', 'Mankind', '8901234567893', 'Antihistamine', FALSE, 60, 120),
('Omeprazole', 'Omeprazole', 'Capsule', '20mg', 'Lupin', '8901234567894', 'Proton Pump Inhibitor', TRUE, 25, 50),
('Metformin', 'Metformin HCl', 'Tablet', '500mg', 'USV Ltd', '8901234567895', 'Antidiabetic', TRUE, 40, 80),
('Atorvastatin', 'Atorvastatin', 'Tablet', '10mg', 'Ranbaxy', '8901234567896', 'Statin', TRUE, 35, 70),
('Aspirin', 'Acetylsalicylic Acid', 'Tablet', '75mg', 'Bayer', '8901234567897', 'Antiplatelet', FALSE, 50, 100),
('Vitamin C', 'Ascorbic Acid', 'Tablet', '1000mg', 'HealthKart', '8901234567898', 'Vitamin', FALSE, 100, 200),
('Azithromycin', 'Azithromycin', 'Tablet', '500mg', 'Alkem', '8901234567899', 'Antibiotic', TRUE, 20, 40);

-- Insert medicine interactions
INSERT INTO medicine_interactions (medicine_id_1, medicine_id_2, interaction_type, description) VALUES
(1, 3, 'moderate', 'Both have analgesic properties; combined use may increase risk of gastrointestinal bleeding'),
(2, 10, 'minor', 'No significant interaction but monitor patient response'),
(3, 8, 'severe', 'Increased risk of bleeding when NSAIDs combined with aspirin'),
(6, 7, 'moderate', 'Both affect liver enzymes; monitor liver function tests');

-- Insert batches using the function
SELECT add_batch(1, 1, 'PARA2024001', CURRENT_DATE + INTERVAL '15 days', CURRENT_DATE - INTERVAL '60 days', 500, 5.00, 8.00, 'BAR001', TRUE);
SELECT add_batch(2, 2, 'AMOX2024001', CURRENT_DATE + INTERVAL '45 days', CURRENT_DATE - INTERVAL '30 days', 200, 15.00, 25.00, 'BAR002', TRUE);
SELECT add_batch(3, 1, 'IBU2024001', CURRENT_DATE + INTERVAL '180 days', CURRENT_DATE - INTERVAL '45 days', 300, 7.00, 12.00, 'BAR003', FALSE);
SELECT add_batch(4, 3, 'CET2024001', CURRENT_DATE + INTERVAL '5 days', CURRENT_DATE - INTERVAL '90 days', 150, 4.00, 9.00, 'BAR004', TRUE);
SELECT add_batch(5, 2, 'OME2024001', CURRENT_DATE + INTERVAL '120 days', CURRENT_DATE - INTERVAL '20 days', 180, 12.00, 20.00, 'BAR005', TRUE);
SELECT add_batch(6, 3, 'MET2024001', CURRENT_DATE + INTERVAL '200 days', CURRENT_DATE - INTERVAL '30 days', 250, 3.50, 7.00, 'BAR006', FALSE);
SELECT add_batch(9, 4, 'VIT2024001', CURRENT_DATE + INTERVAL '365 days', CURRENT_DATE - INTERVAL '10 days', 500, 2.00, 5.00, 'BAR009', FALSE);
SELECT add_batch(10, 2, 'AZI2024001', CURRENT_DATE + INTERVAL '90 days', CURRENT_DATE - INTERVAL '15 days', 100, 20.00, 35.00, 'BAR010', TRUE);

-- Insert prescriptions
INSERT INTO prescriptions (prescription_number, patient_name, patient_phone, doctor_name, doctor_license, issue_date, expiry_date, status) VALUES
('RX2024001', 'Rahul Verma', '+91-9988776655', 'Dr. Sanjay Gupta', 'DMC12345', CURRENT_DATE - INTERVAL '2 days', CURRENT_DATE + INTERVAL '28 days', 'active'),
('RX2024002', 'Sneha Kapoor', '+91-9876543220', 'Dr. Meera Patel', 'DMC12346', CURRENT_DATE - INTERVAL '5 days', CURRENT_DATE + INTERVAL '25 days', 'active');

-- Run scheduled tasks
SELECT mark_expired_batches();

-- Display results
SELECT * FROM active_alerts_view;
SELECT * FROM pharmacist_dashboard WHERE stock_status != 'OK';
SELECT * FROM manager_analytics;
SELECT * FROM supplier_performance;
