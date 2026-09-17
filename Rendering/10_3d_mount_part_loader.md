# `C3DMount` — mount mesh / texture part loader

**Scope:** Managed port of the native `C3DMount` factory + part-info loader pair
that resolves a mount type id into a populated `RolePartInfo` record (mesh +
texture + speed + future-decoded trailing fields). Distinct from the existing
`MountTypeDatRecord` (`mounttype.dat` action-scale / color / sound table) — this
slice is the 3D-mesh side of the mount system.

---

## Retail oracle (`40_tools/fight-master/my_client/3DBaseCode/3DMount.{h,cpp}`)

Class surface (retail signatures, complete — header is 32 lines, cpp is 75 lines):

```cpp
class C3DMount : public C3DRolePart {
public:
    C3DMount();
    virtual ~C3DMount();

    static C3DMount* CreateNew(OBJID idType);   // factory: new + Create + delete-on-fail

    BOOL Create(OBJID idType);                   // loads RolePartInfo into m_infoPart
};
```

`Create(idType)` retail flow (`3DMount.cpp:46-72`):

```cpp
if (idType == ID_NONE) return false;
char szTitle[256];
sprintf(szTitle, "Mount%u", idType);
RolePartInfo* p = g_obj3DRoleData.GetRoleRartInfo(ROLEPARTINFO_MOUNT, szTitle);
if (!p) ErrorOut("%s not found in %s!", szTitle, "ini/Mount.ini");
m_infoPart.idMesh     = p->idMesh;
m_infoPart.idTexture  = p->idTexture;
m_infoPart.p3DMesh    = g_objGameDataSet.Get3DObj(p->idMesh);
m_infoPart.idTexture2 = p->idTexture2;
m_infoPart.fCurrentX  = 0.0f;
m_infoPart.fCurrentY  = 0.0f;
m_infoPart.fSpeedX    = p->fMoveRateX;
m_infoPart.fSpeedY    = p->fMoveRateY;
SetDefaultMotion();
m_idType = idType;
return true;
```

The struct retail consumes (`3DRolePart.h:24-35`):

```cpp
typedef struct {
    OBJID    idMesh;
    OBJID    idTexture;
    int      nType;
    C3DObj*  p3DMesh;
    OBJID    idTexture2;
    float    fSpeedX;
    float    fSpeedY;
    float    fCurrentX;
    float    fCurrentY;
} C3DObjPartInfo;   // 36 bytes
```

---

## client-5517 evolution (`GameRole.dll`)

5517 keeps the same external shape but rewrote the loader internals. Verified at
the BNinja decompilation of `C3DMount_CreateNew` (factory, `0x10001650`) and
`C3DMount_Create` (loader, `0x10001720`):

| Concern | Retail | 5517 |
|---|---|---|
| Lookup key | section name `"Mount<idType>"` | numeric `(category=4, idType)` |
| Lookup call | `g_obj3DRoleData.GetRoleRartInfo(ROLEPARTINFO_MOUNT, name)` | `(*RoleDataQuery() + 8)(4, idType)` |
| Field copy | one-by-one with explicit `fCurrentX/Y = 0` | bulk `memcpy(arg1+0xb0, partInfo, 0x74)` |
| Record size | 36 bytes (`C3DObjPartInfo`) | 116 bytes (`0x74`) — 80 trailing bytes added |
| Default motion | `SetDefaultMotion()` call after copy | dropped — motion sourced elsewhere |
| Error message | `"Mount%u not found in %s!"` | `"[%u] not found in %s!"` |
| Object footprint | (retail size unknown but base C3DRolePart + 36 bytes) | 0x124 = 292 bytes |

The factory `C3DMount_CreateNew` is otherwise byte-faithful to retail:

```
C3DMount_CreateNew(idType):
    if (idType == 0) return NULL
    self = operator new(0x124)
    if (!self) return NULL
    C3DMount_Constructor(self)
    if (!C3DMount_Create(self, idType)):
        self->vtable->dtor(delete=1)   // (**self)(1)
        return NULL
    return self
```

The constructor `C3DMount_Constructor` (`0x10001600`) calls
`sub_10004430(this)` (the C3DRolePart base constructor) and assigns the
C3DMount vtable at `data_1001a1ac`. Retail body is empty per `3DMount.cpp:17`.

---

## Managed port seams (`Conquer.Assets.RolePart`)

```csharp
public enum RolePartInfoCategory
{
    Body = 0, Head = 1, Armet = 2, Weapon = 3, Mount = 4
}

public readonly record struct RolePartInfo(
    uint MeshId, uint TextureId, int Type,
    object? Mesh3DHandle,
    uint Texture2Id,
    float SpeedX, float SpeedY,
    float CurrentX, float CurrentY,
    byte[] TrailingOpaqueBytes)
{
    public const int RetailRecordSize = 36;
    public const int Native5517RecordSize = 0x74;        // 116
    public const int TrailingOpaqueSize = 0x74 - 36;     // 80
}

public interface IRolePartInfoSource
{
    RolePartInfo? Resolve(RolePartInfoCategory category, uint typeId);
}

public interface IRolePartInfoErrorReporter
{
    void ReportRecordMissing(uint typeId, string iniPath);
}

public sealed class C3DMount
{
    public const string MountIniPath = "ini/Mount.ini";

    public uint TypeId { get; }
    public RolePartInfo PartInfo { get; }

    public static C3DMount? CreateNew(
        uint typeId,
        IRolePartInfoSource partInfoSource,
        IRolePartInfoErrorReporter? errorReporter = null);
}
```

### Invariants (tested)

- `typeId == 0` → returns `null` without consulting the source or reporter (retail/5517 `ID_NONE` short-circuit at line 28-31 / `0x1000172d`).
- Source miss → returns `null` and reports the missing record with the exact 5517 message text via `IRolePartInfoErrorReporter` (passes `"ini/Mount.ini"` verbatim).
- Source hit → returns a `C3DMount` with `TypeId` = input and `PartInfo` = the source record verbatim.
- Resolution always queries the `Mount` category exclusively, even when the source has records under other categories at the same id.
- `null` source argument throws `ArgumentNullException(paramName: "partInfoSource")`.
- `RolePartInfo` constants line up with the 5517 record sizes (36, 116, 80).

8 tests, all green via:

```
dotnet test tests/Conquer.Tests/Conquer.Tests.csproj \
  --filter "FullyQualifiedName~C3DMountTests" --nologo
```

### What this port does **not** cover

- The retail `nType` / `p3DMesh` resolution chain — managed `Mesh3DHandle` is
  modelled as `object?` until the C3DObj cache layer lands. Concrete callers
  inject their own mesh-resolver in front of `IRolePartInfoSource` if they
  need the resolved mesh.
- The 80-byte trailing payload in 5517's widened `RolePartInfo` struct — kept
  as `TrailingOpaqueBytes` until field-by-field decoding lands. The bulk-copy
  semantics of `0x74` are still preserved end to end (bytes round-trip).
- Mount draw / matrix composition — that lives downstream in
  `GameRole.dll:sub_10003500` (the C3DRole::Draw equivalent), already covered
  by the managed `Role3DClientSceneMultiPartRenderStage` slice (Codex slice B).
- `SetDefaultMotion` — the retail call dropped in 5517; motion is sourced from
  the visual-track configurator now.

---

## Cross-refs

- **Retail source:** `40_tools/fight-master/my_client/3DBaseCode/3DMount.{h,cpp}`,
  `40_tools/fight-master/my_client/3DBaseCode/3DRolePart.{h,cpp}`
- **5517 native:** `GameRole.dll` — `C3DMount_CreateNew` (`0x10001650`),
  `C3DMount_Create` (`0x10001720`), `C3DMount_Constructor` (`0x10001600`).
  All three renamed + commented in BNinja with managed parity links
- **Managed code:** `10_work/src/Conquer.Assets/RolePart/C3DMount.cs`
- **Tests:** `10_work/tests/Conquer.Tests/Assets/RolePart/C3DMountTests.cs` (8 tests)
- **Adjacent managed:** `10_work/src/Conquer.Assets/GraphicDb/MountTypeDatRecord.cs`
  (the `mounttype.dat` action-scale / color / sound table — different layer
  of the mount system, both consumed together by the live render pipeline)
- **Render-time consumer:** `Role3DClientSceneMultiPartRenderStage.cs`
  (renders the mount slot via `v_mount` virtual motion attachment as part of
  the multi-part composite pipeline)
