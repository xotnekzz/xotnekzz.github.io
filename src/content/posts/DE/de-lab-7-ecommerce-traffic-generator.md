---
title: "[Data Engineering Lab] #7. 실시간 이커머스 트래픽 생성기"
date: 2026-01-02
tags:
  - Python
  - CDC
  - DataEngineering
  - Lab
featured: false
draft: false
---

실제 이커머스 서비스 환경을 재현하기 위한 데이터 스키마 설계와 트래픽 생성기 파이썬 코드를 구현하도록 하겠습니다.

## 1. 데이터 설계

- users: 서비스를 이용하는 고객 정보
- products: 판매되는 상품정보
- orders: 고객이 상품을 구매할 때 발생하는 핵심 트랜잭션 데이터

### DDL

```sql
USE demo_db;

-- 1. 유저 테이블
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. 상품 테이블 (기초 데이터)
CREATE TABLE IF NOT EXISTS products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    category VARCHAR(50),
    price DECIMAL(10, 2),
    stock INT DEFAULT 100
);

-- 3. 주문 테이블 w
CREATE TABLE IF NOT EXISTS orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    product_id INT,
    quantity INT,
    total_price DECIMAL(10, 2),
    status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, SHIPPED, CANCELLED
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);
```

## 2. Pyhton 트래픽 생성기 구현

설계된 테이블에 데이터를 쏟아부을 Python 트래픽 생성기를 구현 합니다.

### 트래픽 생성 시나리오

1. 초기화: `products` 테이블에 기초 상품 데이터(마우스, 키보드 등)를 미리 넣어둡니다.
```
INSERT INTO products (name, category, price) VALUES
('Gaming Mouse', 'Electronics', 59.99),
('Mechanical Keyboard', 'Electronics', 129.50),
('Coffee Mug', 'Home', 12.00),
('Hoodie', 'Apparel', 45.00),
('USB-C Cable', 'Electronics', 9.99);
```
2. 트래픽 생성
	- 20% 확률로 새로운 유저 가입
		- 70% 확률로 새로운 상품 주문
		- 10% 확률로 기존 주문의 배송 상태 변경 또는 취소
```python
import mysql.connector
import time
import random
from faker import Faker
from datetime import datetime

# DB 설정 (Localhost -> Docker MariaDB)
DB_CONFIG = {
    'host': '127.0.0.1',
    'port': 3306,
    'user': 'root',       # 또는 user
    'password': 'root',   # 또는 userpw (docker-compose 설정 따름)
    'database': 'demo_db'
}

fake = Faker()

def get_connection():
    return mysql.connector.connect(**DB_CONFIG)

def generate_traffic():
    conn = get_connection()
    cursor = conn.cursor()

    print("Starting Traffic Generator... (Press Ctrl+C to stop)")

    try:
        while True:
            action = random.choices(['INSERT', 'UPDATE', 'DELETE'], weights=[70, 20, 10])[0]

            if action == 'INSERT':
                # 1. 새 유저 생성 (가끔)
                if random.random() < 0.2:
                    name = fake.name()
                    email = fake.email()
                    cursor.execute("INSERT INTO users (name, email) VALUES (%s, %s)", (name, email))
                    print(f"[USER] Created: {name}")

                # 2. 주문 생성 (자주)
                # 랜덤 유저와 상품 ID 가져오기
                cursor.execute("SELECT id FROM users ORDER BY RAND() LIMIT 1")
                user = cursor.fetchone()
                cursor.execute("SELECT id, price FROM products ORDER BY RAND() LIMIT 1")
                product = cursor.fetchone()

                if user and product:
                    u_id = user[0]
                    p_id, price = product
                    qty = random.randint(1, 5)
                    total = float(price) * qty

                    sql = """INSERT INTO orders (user_id, product_id, quantity, total_price, status) 
                             VALUES (%s, %s, %s, %s, 'PENDING')"""
                    cursor.execute(sql, (u_id, p_id, qty, total))
                    print(f"[ORDER] New Order! User {u_id} bought Item {p_id} ($ {total})")

            elif action == 'UPDATE':
                # 주문 상태 변경 (PENDING -> SHIPPED)
                cursor.execute("SELECT id FROM orders WHERE status='PENDING' ORDER BY RAND() LIMIT 1")
                target = cursor.fetchone()
                if target:
                    cursor.execute("UPDATE orders SET status='SHIPPED' WHERE id=%s", (target[0],))
                    print(f"[UPDATE] Order {target[0]} status changed to SHIPPED")

            elif action == 'DELETE':
                # 주문 취소 (데이터 삭제)
                cursor.execute("SELECT id FROM orders ORDER BY RAND() LIMIT 1")
                target = cursor.fetchone()
                if target:
                    cursor.execute("DELETE FROM orders WHERE id=%s", (target[0],))
                    print(f"[DELETE] Order {target[0]} was cancelled (Deleted)")

            conn.commit()

            # 속도 조절 (0.5초 ~ 2초 사이 랜덤 대기)
            sleep_time = random.uniform(0.5, 2.0)
            time.sleep(sleep_time)

    except KeyboardInterrupt:
        print("\nStopping generator...")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        cursor.close()
        conn.close()

if __name__ == "__main__":
    generate_traffic()
```

## 3. 실행 및 Binlog 확인

### 실행

2번에서 작성한 파이썬 코드를 실행합니다.

```sql
(venv) tskim@MacBook-Pro mariadb % python gen_data.py
🚀 Starting Traffic Generator... (Press Ctrl+C to stop)
[USER] Created: Christian Gonzalez
[ORDER] New Order! User 1 bought Item 4 ($ 135.0)
[ORDER] New Order! User 1 bought Item 4 ($ 90.0)
[USER] Created: Erin Chen
[ORDER] New Order! User 1 bought Item 4 ($ 135.0)
[ORDER] New Order! User 2 bought Item 4 ($ 135.0)
[ORDER] New Order! User 1 bought Item 2 ($ 259.0)
[UPDATE] Order 4 status changed to SHIPPED
[USER] Created: Benjamin Mendez
[ORDER] New Order! User 3 bought Item 4 ($ 135.0)
[ORDER] New Order! User 1 bought Item 3 ($ 12.0)
```

### Binlog 확인

mariadb 컨테이너에 접속하여 아래 코드블럭과 같이 mysql-bin 로그파일이 잘쌓이고 있는지 확인합니다.

```ruby
root@a37d19d77728:/var/lib/mysql# ls -al | grep mysql-bin
-rw-rw---- 1 mysql mysql      3106 Dec 27 14:21 mysql-bin.000001
-rw-rw---- 1 mysql mysql       365 Dec 31 04:25 mysql-bin.000002
-rw-rw---- 1 mysql mysql     12706 Jan  1 14:59 mysql-bin.000003
-rw-rw---- 1 mysql mysql        57 Jan  1 14:58 mysql-bin.index
root@a37d19d77728:/var/lib/mysql# tail -10f mysql-bin.000003
��ViphA�)demo_dborder�
P>(��a��ViphG7��'\`PENDINGiV��iV��܋m]��ViphV*uH���ËVi�ph*�'
                                                          gm.�ËVi�ph4�*DELETE FROM orders WHERE id=2�
?�ËViphA�*demo_dborder�
P>U}��ËViphG<��ZPENDINGiV��iV��+��ËViph[+y[&b7ċVi�ph*�(
                                                       W��NċVi�phE�+UPDATE orders SET status='SHIPPED' WHERE id=14c%ċViphA
                                                                                                                          ,demo_dborder�
P>��)TċViphny����2PENDINGiV��iV����2SHIPPEDiV��iV���׉�ċViph�,|)U�nƋVi�ph*�)
                                                                           ��ƋVi�ph�a-INSERT INTO orders (user_id, product_id, quantity, total_price, status)
                             VALUES (4, 4, 3, 135.0, 'PENDING')!Q�ƋViphA�-demo_dborder�
P>�px�ƋViphG����PENDINGiV��iV��7/ƋVip.���ǋVi�ph*2*
                                                   ��ǋVi�phe�.INSERT INTO users (name, email) VALUES ('Cassie Smith', 'megan63@example.net')+f��ǋViph;�.demo_dbusers���/p�ǋViphM/�
                                                                                                                                                                                  Cassie Smithmegan63@example.netiV�����ǋVi�ph��/INSERT INTO orders (user_id, product_id, quantity, total_price, status)
                             VALUES (1, 2, 1, 129.5, 'PENDING')��\�ǋViphA�/demo_dborder�
P>Aֱ�ǋViphGF���2PENDINGiV��iV��c79�ǋViphe0��M

                                            ȋVi�ph*�+
                                                     bghHȋVi�phE�0UPDATE orders SET status='SHIPPED' WHERE id=19�qz�ȋViphA1demo_dborder�
P>!��=ȋViphn�����PENDINGiV��iV����SHIPPEDiV��iV�Ȫ�B�ȋViph�1�ݪ�<
```

