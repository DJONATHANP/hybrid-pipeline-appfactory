import json
import time
import os

def lambda_handler(event, context):
    """
    Función de AWS Lambda que simula un procesamiento intensivo.
    """
    start_time = time.time()
    try:
        # Autorización simple por API Key
        try:
            headers = event.get('headers', {}) or {}
            provided_key = headers.get('x-api-key') or headers.get('X-Api-Key')
            expected_key = os.environ.get('LAMBDA_API_KEY')
            if not expected_key or provided_key != expected_key:
                return {
                    'statusCode': 401,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({'status': 'unauthorized'})
                }
        except Exception as auth_err:
            print({'auth_error': str(auth_err), 'event_headers': event.get('headers')})
            return {
                'statusCode': 401,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'status': 'unauthorized'})
            }

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
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps(processing_result)
        }
    except Exception as e:
        # Log de diagnóstico para ver el motivo del 500 en CloudWatch
        print({
            'error': str(e),
            'event_sample': {
                'version': event.get('version'),
                'routeKey': event.get('routeKey'),
                'rawPath': event.get('rawPath'),
                'rawQueryString': event.get('rawQueryString')
            }
        })
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'status': 'error', 'message': 'internal_error'})
        }
