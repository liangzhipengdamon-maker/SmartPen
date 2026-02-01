import json
import urllib.request

OPENAPI = "http://127.0.0.1:8000/openapi.json"
PATH = "/api/score/comprehensive"
METHOD = "post"

def main():
    data = json.load(urllib.request.urlopen(OPENAPI))
    op = data["paths"][PATH][METHOD]
    print("=== Endpoint ===")
    print(METHOD.upper(), PATH)
    print("\n=== Summary ===")
    print(op.get("summary"))

    req = op.get("requestBody", {})
    content = req.get("content", {})
    app_json = content.get("application/json", {})
    schema = app_json.get("schema", {})

    print("\n=== requestBody schema (raw) ===")
    print(json.dumps(schema, ensure_ascii=False, indent=2))

    # If it's a $ref, resolve it
    if "$ref" in schema:
        ref = schema["$ref"]
        name = ref.split("/")[-1]
        resolved = data["components"]["schemas"][name]
        print("\n=== requestBody schema (resolved) ===")
        print(json.dumps(resolved, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
