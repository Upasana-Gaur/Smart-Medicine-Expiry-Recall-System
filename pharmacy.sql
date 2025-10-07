DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS predicted_demand CASCADE;
DROP TABLE IF EXISTS alerts CASCADE;
DROP TABLE IF EXISTS recalls CASCADE;
DROP TABLE IF EXISTS sales CASCADE;
DROP TABLE IF EXISTS batches CASCADE;
DROP TABLE IF EXISTS medicines CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;
DROP TABLE IF EXISTS users CASCADE;

CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100),
    role VARCHAR(20) CHECK (role IN ('pharmacist', 'manager', 'admin')) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE suppliers (
    supplier_id SERIAL PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL,
    contact_person VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(20),
    address TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

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
    requires_prescription BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

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
    barcode VARCHAR(100),
    is_recalled BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(medicine_id, batch_number)
);

CREATE TABLE sales (
    sale_id SERIAL PRIMARY KEY,
    batch_id INTEGER REFERENCES batches(batch_id) ON DELETE RESTRICT,
    quantity_sold INTEGER NOT NULL CHECK (quantity_sold > 0),
    sale_price DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    customer_info TEXT,
    sold_by INTEGER REFERENCES users(user_id),
    sale_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE recalls (
    recall_id SERIAL PRIMARY KEY,
    batch_id INTEGER REFERENCES batches(batch_id) ON DELETE CASCADE,
    recall_reason TEXT NOT NULL,
    recall_date DATE NOT NULL,
    announced_by VARCHAR(100),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'resolved', 'cancelled')),
    instructions TEXT,
    created_by INTEGER REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE alerts (
    alert_id SERIAL PRIMARY KEY,
    batch_id INTEGER REFERENCES batches(batch_id) ON DELETE CASCADE,
    alert_type VARCHAR(20) CHECK (alert_type IN ('expiry', 'recall', 'low_stock')) NOT NULL,
    alert_message TEXT NOT NULL,
    severity VARCHAR(10) CHECK (severity IN ('low', 'medium', 'high')) DEFAULT 'medium',
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_by INTEGER REFERENCES users(user_id),
    acknowledged_at TIMESTAMP
);

CREATE TABLE predicted_demand (
    prediction_id SERIAL PRIMARY KEY,
    medicine_id INTEGER REFERENCES medicines(medicine_id) ON DELETE CASCADE,
    predicted_date DATE NOT NULL,
    predicted_quantity INTEGER NOT NULL,
    confidence_level DECIMAL(3,2) CHECK (confidence_level >= 0 AND confidence_level <= 1),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE audit_log (
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    record_id INTEGER NOT NULL,
    action VARCHAR(10) CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values JSONB,
    new_values JSONB,
    changed_by INTEGER REFERENCES users(user_id),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Functions
CREATE OR REPLACE FUNCTION add_batch(
    p_medicine_id INTEGER,
    p_supplier_id INTEGER,
    p_batch_number VARCHAR,
    p_expiry_date DATE,
    p_manufacture_date DATE,
    p_quantity INTEGER,
    p_cost_price DECIMAL,
    p_selling_price DECIMAL,
    p_barcode VARCHAR
) RETURNS INTEGER AS $$
DECLARE
    new_batch_id INTEGER;
BEGIN
    INSERT INTO batches (
        medicine_id, supplier_id, batch_number, expiry_date, 
        manufacture_date, quantity, cost_price, selling_price, barcode
    ) VALUES (
        p_medicine_id, p_supplier_id, p_batch_number, p_expiry_date,
        p_manufacture_date, p_quantity, p_cost_price, p_selling_price, p_barcode
    ) RETURNING batch_id INTO new_batch_id;
    
    IF p_expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN
        INSERT INTO alerts (batch_id, alert_type, alert_message, severity)
        VALUES (new_batch_id, 'expiry', 
                'Batch ' || p_batch_number || ' expires within 30 days', 'high');
    END IF;
    
    RETURN new_batch_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION record_sale(
    p_batch_id INTEGER,
    p_quantity_sold INTEGER,
    p_sale_price DECIMAL,
    p_customer_info TEXT,
    p_sold_by INTEGER
) RETURNS INTEGER AS $$
DECLARE
    available_quantity INTEGER;
    new_sale_id INTEGER;
    medicine_name VARCHAR;
BEGIN
    SELECT quantity INTO available_quantity 
    FROM batches WHERE batch_id = p_batch_id;
    
    IF available_quantity < p_quantity_sold THEN
        RAISE EXCEPTION 'Insufficient stock. Available: %, Requested: %', 
                        available_quantity, p_quantity_sold;
    END IF;
    
    INSERT INTO sales (batch_id, quantity_sold, sale_price, total_amount, customer_info, sold_by)
    VALUES (p_batch_id, p_quantity_sold, p_sale_price, p_quantity_sold * p_sale_price, 
            p_customer_info, p_sold_by)
    RETURNING sale_id INTO new_sale_id;
    
    SELECT m.name INTO medicine_name
    FROM medicines m
    JOIN batches b ON m.medicine_id = b.medicine_id
    WHERE b.batch_id = p_batch_id;
    
    IF (available_quantity - p_quantity_sold) <= 10 THEN
        INSERT INTO alerts (batch_id, alert_type, alert_message, severity)
        VALUES (p_batch_id, 'low_stock', 
                'Low stock alert for ' || medicine_name || '. Remaining: ' || (available_quantity - p_quantity_sold), 
                'medium');
    END IF;
    
    RETURN new_sale_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_near_expiry_batches(days_threshold INTEGER DEFAULT 30)
RETURNS TABLE (
    batch_id INTEGER,
    batch_number VARCHAR,
    medicine_name VARCHAR,
    expiry_date DATE,
    days_until_expiry INTEGER,
    quantity INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.batch_id,
        b.batch_number,
        m.name as medicine_name,
        b.expiry_date,
        (b.expiry_date - CURRENT_DATE) as days_until_expiry,
        b.quantity
    FROM batches b
    JOIN medicines m ON b.medicine_id = m.medicine_id
    WHERE b.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + (days_threshold || ' days')::INTERVAL
    AND b.quantity > 0
    ORDER BY b.expiry_date ASC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_recall(
    p_batch_id INTEGER,
    p_recall_reason TEXT,
    p_recall_date DATE,
    p_announced_by VARCHAR,
    p_instructions TEXT,
    p_created_by INTEGER
) RETURNS INTEGER AS $$
DECLARE
    new_recall_id INTEGER;
    batch_info RECORD;
BEGIN
    SELECT b.batch_number, m.name as medicine_name 
    INTO batch_info
    FROM batches b
    JOIN medicines m ON b.medicine_id = m.medicine_id
    WHERE b.batch_id = p_batch_id;
    
    INSERT INTO recalls (batch_id, recall_reason, recall_date, announced_by, instructions, created_by)
    VALUES (p_batch_id, p_recall_reason, p_recall_date, p_announced_by, p_instructions, p_created_by)
    RETURNING recall_id INTO new_recall_id;
    
    INSERT INTO alerts (batch_id, alert_type, alert_message, severity)
    VALUES (p_batch_id, 'recall', 
            'RECALL: ' || batch_info.medicine_name || ' (Batch: ' || batch_info.batch_number || ') - ' || p_recall_reason, 
            'high');
    
    UPDATE batches SET is_recalled = TRUE WHERE batch_id = p_batch_id;
    
    RETURN new_recall_id;
END;
$$ LANGUAGE plpgsql;

-- Create Triggers
CREATE OR REPLACE FUNCTION update_batch_quantity()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE batches 
    SET quantity = quantity - NEW.quantity_sold 
    WHERE batch_id = NEW.batch_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_stock_after_sale
    AFTER INSERT ON sales
    FOR EACH ROW
    EXECUTE FUNCTION update_batch_quantity();

CREATE OR REPLACE FUNCTION check_expiry_alerts()
RETURNS void AS $$
BEGIN
    INSERT INTO alerts (batch_id, alert_type, alert_message, severity)
    SELECT 
        b.batch_id,
        'expiry',
        'Batch ' || b.batch_number || ' expires on ' || b.expiry_date,
        CASE 
            WHEN b.expiry_date <= CURRENT_DATE + INTERVAL '7 days' THEN 'high'
            WHEN b.expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'medium'
            ELSE 'low'
        END
    FROM batches b
    WHERE b.expiry_date <= CURRENT_DATE + INTERVAL '30 days'
    AND b.quantity > 0
    AND NOT EXISTS (
        SELECT 1 FROM alerts a 
        WHERE a.batch_id = b.batch_id 
        AND a.alert_type = 'expiry' 
        AND a.is_acknowledged = FALSE
    );
END;
$$ LANGUAGE plpgsql;

-- Create Views
CREATE VIEW pharmacist_dashboard AS
SELECT 
    m.medicine_id,
    m.name as medicine_name,
    m.dosage_form,
    m.strength,
    b.batch_id,
    b.batch_number,
    b.expiry_date,
    b.quantity as current_stock,
    b.selling_price,
    b.is_recalled,
    CASE 
        WHEN b.is_recalled THEN 'RECALLED'
        WHEN b.expiry_date <= CURRENT_DATE THEN 'EXPIRED'
        WHEN b.expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'NEAR_EXPIRY'
        ELSE 'OK'
    END as stock_status
FROM medicines m
JOIN batches b ON m.medicine_id = b.medicine_id
WHERE b.quantity > 0 AND m.is_active = TRUE;

CREATE VIEW manager_analytics AS
SELECT 
    m.medicine_id,
    m.name as medicine_name,
    SUM(b.quantity) as total_stock,
    COUNT(DISTINCT b.batch_id) as active_batches,
    COUNT(CASE WHEN b.expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN 1 END) as near_expiry_batches,
    COUNT(CASE WHEN b.is_recalled THEN 1 END) as recalled_batches,
    COALESCE(SUM(s.quantity_sold), 0) as total_sold_last_30_days,
    COALESCE(SUM(s.total_amount), 0) as revenue_last_30_days
FROM medicines m
LEFT JOIN batches b ON m.medicine_id = b.medicine_id
LEFT JOIN sales s ON b.batch_id = s.batch_id AND s.sale_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY m.medicine_id, m.name;

CREATE VIEW active_alerts_view AS
SELECT 
    a.alert_id,
    a.alert_type,
    a.alert_message,
    a.severity,
    a.generated_at,
    m.name as medicine_name,
    b.batch_number,
    a.is_acknowledged,
    u.username as acknowledged_by_name
FROM alerts a
JOIN batches b ON a.batch_id = b.batch_id
JOIN medicines m ON b.medicine_id = m.medicine_id
LEFT JOIN users u ON a.acknowledged_by = u.user_id
WHERE a.is_acknowledged = FALSE
ORDER BY a.severity DESC, a.generated_at DESC;

-- Insert Sample Data
INSERT INTO users (username, password_hash, role, full_name, email) VALUES
('admin', 'hashed_password_123', 'admin', 'System Administrator', 'admin@pharmacy.com'),
('manager1', 'hashed_password_456', 'manager', 'John Manager', 'john@pharmacy.com'),
('pharmacist1', 'hashed_password_789', 'pharmacist', 'Alice Pharmacist', 'alice@pharmacy.com');

INSERT INTO suppliers (supplier_name, contact_person, email, phone) VALUES
('MedSupplier Inc', 'Bob Wilson', 'bob@medsupplier.com', '+1-555-0101'),
('PharmaDistributors', 'Sarah Chen', 'sarah@pharmadist.com', '+1-555-0102'),
('HealthCare Supplies', 'Mike Johnson', 'mike@healthcaresupplies.com', '+1-555-0103');

INSERT INTO medicines (name, generic_name, dosage_form, strength, manufacturer, barcode) VALUES
('Paracetamol', 'Acetaminophen', 'Tablet', '500mg', 'MedManufacturer', '123456789012'),
('Amoxicillin', 'Amoxicillin', 'Capsule', '250mg', 'PharmaCorp', '123456789013'),
('Ibuprofen', 'Ibuprofen', 'Tablet', '400mg', 'HealthMakers', '123456789014'),
('Vitamin C', 'Ascorbic Acid', 'Tablet', '1000mg', 'Vitamins Inc', '123456789015'),
('Cetirizine', 'Cetirizine', 'Tablet', '10mg', 'AllergyCare', '123456789016');

INSERT INTO batches (medicine_id, supplier_id, batch_number, expiry_date, quantity, cost_price, selling_price) VALUES
(1, 1, 'BATCH001', CURRENT_DATE + INTERVAL '15 days', 100, 5.00, 8.00),
(2, 2, 'BATCH002', CURRENT_DATE + INTERVAL '60 days', 50, 15.00, 25.00),
(3, 1, 'BATCH003', CURRENT_DATE + INTERVAL '200 days', 200, 7.00, 12.00),
(4, 3, 'BATCH004', CURRENT_DATE + INTERVAL '5 days', 30, 3.00, 6.00),
(5, 2, 'BATCH005', CURRENT_DATE + INTERVAL '300 days', 150, 4.00, 9.00);

-- Test the functions
SELECT add_recall(4, 'Contamination found during quality check', CURRENT_DATE, 'FDA', 'Return all stocks immediately', 1);

-- Generate expiry alerts
SELECT check_expiry_alerts();

-- View the results
SELECT * FROM active_alerts_view;
SELECT * FROM pharmacist_dashboard;
SELECT * FROM get_near_expiry_batches(30); how to make this on postgresql step by step i dont know how to run postresql