/* * computeparticles.slang - Modified for Collision Mesh
 */

// 1. Define the Unit Cube (The "Paint Brush" geometry)
// We hardcode this in the shader for simplicity, or you can pass it as a Vertex Buffer.
// For this step, let's assume you pass the vertices via Vertex Buffer, 
// and this shader positions them based on the SSBO data.

struct VSInput
{
    // Per-vertex data (The Unit Cube)
    float3 Pos : POSITION0; 
    float3 Normal : NORMAL0;
};

struct VSOutput
{
    float4 Pos : SV_POSITION;
    float4 Color : COLOR0;
    float3 WorldPos : POSITION1;
};

// 2. The Physics Object Structure
struct CollisionObject
{
    float3 pos;       // Center position
    float3 vel;       // Velocity
    float4 rotation;  // Quaternion (or axis-angle)
    float3 scale;     // .xy = 2D size, .z = Extrusion amount
    float3 color;     // Color of the object
    int shapeType;    // 0 = Cube, 1 = TrianglePrism
};

// Binding 0 : Previous Frame Data
[[vk::binding(0, 0)]] RWStructuredBuffer<CollisionObject> objectsIn;
// Binding 1 : Current Frame Data
[[vk::binding(1, 0)]] RWStructuredBuffer<CollisionObject> objectsOut;

struct UBO
{
    float deltaT;
    float destX;
    float destY;
    int objectCount;
    float4x4 viewProj; // Need View/Projection matrix for 3D
};
[[vk::binding(2, 0)]] ConstantBuffer<UBO> ubo;

// --- Helper: Rotation ---
float3 rotateVector(float3 v, float4 q) {
    // Simple quaternion rotation application
    return v + 2.0 * cross(q.xyz, cross(q.xyz, v) + q.w * v);
}

[shader("vertex")]
VSOutput vertexMain(VSInput input, uint instanceID : SV_InstanceID)
{
    VSOutput output;

    // 3. Fetch the Instance Data from SSBO using InstanceID
    CollisionObject obj = objectsOut[instanceID]; // Read from 'Out' because Graphics runs after Compute

    // 4. Apply Scale (Extrusion)
    float3 localPos = input.Pos * obj.scale;

    // 5. Apply Rotation
    // (Assuming rotation is identity for now, 0,0,0,1)
    // float3 rotatedPos = rotateVector(localPos, obj.rotation); 
    
    // 6. Apply Translation
    float3 worldPos = localPos + obj.pos;

    // 7. Project to Screen
    output.Pos = mul(ubo.viewProj, float4(worldPos, 1.0));
    output.WorldPos = worldPos;
    output.Color = float4(obj.color, 1.0);

    return output;
}

[shader("fragment")]
float4 fragmentMain(VSOutput input) : SV_Target
{
    // Simple lighting so we can see the 3D shape
    float3 lightDir = normalize(float3(0.5, 1.0, -1.0));
    // We need normals passed through or derived. For flat shading:
    float3 dx = ddx(input.WorldPos);
    float3 dy = ddy(input.WorldPos);
    float3 normal = normalize(cross(dx, dy));
    
    float diff = max(dot(normal, lightDir), 0.2);
    return float4(input.Color.rgb * diff, 1.0);
}

[shader("compute")]
[numthreads(256, 1, 1)]
void computeMain(uint3 GlobalInvocationID : SV_DispatchThreadID)
{
    uint index = GlobalInvocationID.x;
    if (index >= ubo.objectCount) return;

    // Read Previous
    CollisionObject obj = objectsIn[index];
    
    // --- PHYSICS UPDATE (Collision Placeholder) ---
    
    // 1. Gravity
    obj.vel.y += 9.8 * ubo.deltaT * 0.1; 

    // 2. Basic Floor Collision
    if (obj.pos.y > 5.0) {
        obj.pos.y = 5.0;
        obj.vel.y *= -0.5; // Bounce
    }

    // 3. Integrate
    obj.pos += obj.vel * ubo.deltaT;

    // Write Current
    objectsOut[index] = obj;
}
