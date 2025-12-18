use actix_multipart::Multipart;
use actix_web::{get, post, web, App, HttpResponse, HttpServer, Responder};
use futures::{StreamExt, TryStreamExt};
use image::imageops::FilterType;
use image::GenericImageView;
use std::io::Cursor;

#[get("/health")]
async fn health() -> impl Responder {
    HttpResponse::Ok().json(serde_json::json!({"status": "ok"}))
}

#[post("/process")]
async fn process_image(mut payload: Multipart) -> impl Responder {
    let mut processed_image_data = Vec::new();
    let mut filename = String::from("processed.jpg");

    // Iterate over multipart stream
    while let Ok(Some(mut field)) = payload.try_next().await {
        let content_disposition = field.content_disposition();
        let field_name = content_disposition.get_name().unwrap_or("");

        if field_name == "image" {
            // Read all bytes for the image field
            let mut image_bytes = Vec::new();
            while let Some(chunk) = field.next().await {
                match chunk {
                    Ok(data) => image_bytes.extend_from_slice(&data),
                    Err(_) => return HttpResponse::BadRequest().finish(),
                }
            }

            // Process image
            if let Ok(img) = image::load_from_memory(&image_bytes) {
                // Logic: Resize if larger than 1024px width, keeping aspect ratio
                let (width, height) = img.dimensions();
                let target_width = 1024;
                
                let out_img = if width > target_width {
                    img.resize(target_width, (height * target_width) / width, FilterType::Triangle)
                } else {
                    img
                };

                // Encode to JPEG with quality 80
                let mut buffer = Cursor::new(Vec::new());
                if let Err(_) = out_img.write_to(&mut buffer, image::ImageOutputFormat::Jpeg(80)) {
                    return HttpResponse::InternalServerError().finish();
                }
                
                processed_image_data = buffer.into_inner();
            } else {
                 return HttpResponse::BadRequest().body("Invalid image format");
            }
        }
    }

    if processed_image_data.is_empty() {
        return HttpResponse::BadRequest().body("No image found in request");
    }

    HttpResponse::Ok()
        .content_type("image/jpeg")
        .append_header(("Content-Disposition", format!("attachment; filename=\"{}\"", filename)))
        .body(processed_image_data)
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init();
    let port = std::env::var("PORT").unwrap_or_else(|_| "8080".to_string());

    println!("Starting image optimizer service on port {}", port);

    HttpServer::new(|| {
        App::new()
            .service(health)
            .service(process_image)
    })
    .bind(format!("0.0.0.0:{}", port))?
    .run()
    .await
}
