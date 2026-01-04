use actix_web::{get, web, App, HttpResponse, HttpServer, Responder};
use actix_cors::Cors;
use serde::{Deserialize, Serialize};
use sqlx::postgres::PgPoolOptions;
use sqlx::{Pool, Postgres};
use std::sync::Arc;

#[derive(Debug, Serialize, Deserialize)]
struct HealthResponse {
    status: String,
    database: DatabaseStatus,
    extensions: ExtensionStatus,
}

#[derive(Debug, Serialize, Deserialize)]
struct DatabaseStatus {
    connected: bool,
    database_name: String,
    version: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct ExtensionStatus {
    pgvector: ExtensionInfo,
    age: ExtensionInfo,
}

#[derive(Debug, Serialize, Deserialize)]
struct ExtensionInfo {
    available: bool,
    version: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

struct AppState {
    db_pool: Option<Pool<Postgres>>,
}

#[get("/")]
async fn index() -> impl Responder {
    HttpResponse::Ok().body("GCP Cloud Graph Stack - Rust API")
}

#[get("/health")]
async fn health(data: web::Data<Arc<AppState>>) -> impl Responder {
    let mut response = HealthResponse {
        status: "ok".to_string(),
        database: DatabaseStatus {
            connected: false,
            database_name: String::new(),
            version: String::new(),
            error: None,
        },
        extensions: ExtensionStatus {
            pgvector: ExtensionInfo {
                available: false,
                version: None,
                error: None,
            },
            age: ExtensionInfo {
                available: false,
                version: None,
                error: None,
            },
        },
    };

    if let Some(pool) = &data.db_pool {
        // Check database connection and version
        match sqlx::query_as::<_, (String, String)>(
            "SELECT current_database(), version()"
        )
        .fetch_one(pool)
        .await
        {
            Ok((db_name, version)) => {
                response.database.connected = true;
                response.database.database_name = db_name;
                response.database.version = version;
            }
            Err(e) => {
                response.status = "degraded".to_string();
                response.database.error = Some(format!("Database connection error: {}", e));
            }
        }

        // Check pgvector extension
        match sqlx::query_as::<_, (String,)>(
            "SELECT extversion FROM pg_extension WHERE extname = 'vector'"
        )
        .fetch_optional(pool)
        .await
        {
            Ok(Some((version,))) => {
                response.extensions.pgvector.available = true;
                response.extensions.pgvector.version = Some(version);
            }
            Ok(None) => {
                response.extensions.pgvector.error = Some("Extension not installed".to_string());
            }
            Err(e) => {
                response.extensions.pgvector.error = Some(format!("Query error: {}", e));
            }
        }

        // Check AGE extension
        match sqlx::query_as::<_, (String,)>(
            "SELECT extversion FROM pg_extension WHERE extname = 'age'"
        )
        .fetch_optional(pool)
        .await
        {
            Ok(Some((version,))) => {
                response.extensions.age.available = true;
                response.extensions.age.version = Some(version);
            }
            Ok(None) => {
                response.extensions.age.error = Some("Extension not installed".to_string());
            }
            Err(e) => {
                response.extensions.age.error = Some(format!("Query error: {}", e));
            }
        }
    } else {
        response.status = "no_database".to_string();
        response.database.error = Some("No database connection configured".to_string());
    }

    HttpResponse::Ok().json(response)
}

async fn create_db_pool() -> Option<Pool<Postgres>> {
    let db_host = std::env::var("DATABASE_HOST").ok()?;
    let db_port = std::env::var("DATABASE_PORT").unwrap_or_else(|_| "5432".to_string());
    let db_name = std::env::var("DATABASE_NAME").unwrap_or_else(|_| "graph_db".to_string());
    let db_user = std::env::var("DATABASE_USER").unwrap_or_else(|_| "postgres".to_string());
    let db_password = std::env::var("DATABASE_PASSWORD").unwrap_or_default();

    let database_url = if db_password.is_empty() {
        format!(
            "postgresql://{}@{}:{}/{}?sslmode=disable&connect_timeout=3",
            db_user, db_host, db_port, db_name
        )
    } else {
        format!(
            "postgresql://{}:{}@{}:{}/{}?sslmode=disable&connect_timeout=3",
            db_user, db_password, db_host, db_port, db_name
        )
    };

    println!("Connecting to database: {}:{}...", db_host, db_port);

    match PgPoolOptions::new()
        .max_connections(5)
        .acquire_timeout(std::time::Duration::from_secs(3))
        .connect(&database_url)
        .await
    {
        Ok(pool) => {
            println!("✅ Database connection established");
            Some(pool)
        }
        Err(e) => {
            eprintln!("⚠️  Database connection failed: {}", e);
            eprintln!("   API will run in degraded mode (no database)");
            None
        }
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let port = std::env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let address = format!("0.0.0.0:{}", port);

    println!("Starting GCP Cloud Graph Stack API on {}", address);
    
    // Try to create database connection pool with a timeout
    // If it fails, start without database connection
    let db_pool = tokio::time::timeout(
        std::time::Duration::from_secs(5),
        create_db_pool()
    )
    .await
    .ok()
    .flatten();
    
    let app_state = Arc::new(AppState { db_pool });

    HttpServer::new(move || {
        let cors = Cors::default()
            .allow_any_origin()
            .allow_any_method()
            .allow_any_header()
            .max_age(3600);

        App::new()
            .wrap(cors)
            .app_data(web::Data::new(app_state.clone()))
            .service(index)
            .service(health)
    })
    .bind(address)?
    .run()
    .await
}
