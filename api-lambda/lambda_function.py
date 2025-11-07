import json
import time

def lambda_handler(event, context):
    """
    Función de AWS Lambda que simula un procesamiento intensivo.
    """
    start_time = time.time()
    
    # Simulación de un procesamiento de datos o una lógica compleja
    processing_result = {
        "status": "success",
        "service": "AppFactory Hybrid Backend (AWS Lambda)",
        "timestamp": int(start_time * 1000),
        "data": "Datos procesados con éxito en la nube"
    }

    end_time = time.time()
    processing_time_ms = round((end_time - start_time) * 1000, 2)
    processing_result["processing_time_ms"] = processing_time_ms

    # Devuelve una respuesta compatible con API Gateway
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            # CORS para permitir la llamada desde el frontend local (cambia * por tu dominio si es necesario)
            'Access-Control-Allow-Origin': '*' 
        },
        'body': json.dumps(processing_result)
    }
