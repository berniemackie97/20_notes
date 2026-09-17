# DataThread.dll — IDataThread Async Work Queue

## Overview

`DataThread.dll` exports a single factory function `DataThreadCreateNew()` (mangled: `?DataThreadCreateNew@@YAPAVIDataThread@@XZ`) that creates an async work queue backed by a dedicated Win32 worker thread. `GraphicData.dll` loads this DLL dynamically via `LoadLibrary`/`GetProcAddress` at runtime (strings at `0x10032AEA` and `0x10032B16`).

`GameDataSet_Initialize` creates two `IDataThread` instances as resource pools (`+0x2E4` primary, `+0x2E8` secondary). Both are initialized with thread priority 0 (`THREAD_PRIORITY_NORMAL`).

## Object Layout (0xC0 = 192 bytes)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0x00 | 4 | vtable | → `g_DataThread_Vtbl` (0x10009100) |
| +0x04 | 0x30 | completedQueue | Ring buffer: worker → consumer (Queue 0) |
| +0x04 | 1 | .initialized | Queue init flag |
| +0x08 | 0x2C | .ringData | Ring buffer internals |
| +0x30 | 4 | .count | Items available for consumer |
| +0x34 | 0x30 | pendingQueue | Ring buffer: swapped from submission (Queue 1) |
| +0x34 | 1 | .initialized | Queue init flag |
| +0x38 | 0x2C | .ringData | Ring buffer internals |
| +0x60 | 4 | .count | Items pending for worker |
| +0x64 | 0x30 | submissionQueue | Ring buffer: consumer submits here (Queue 2) |
| +0x64 | 1 | .initialized | Queue init flag |
| +0x68 | 0x2C | .ringData | Ring buffer internals |
| +0x90 | 4 | .count | Items awaiting flush to worker |
| +0x94 | 4 | threadHandle | `HANDLE` from `CreateThread` |
| +0x98 | 1 | immediateMode | Flag set by `SetImmediateMode` (vtable +0x08) |
| +0x9C | 4 | workAvailableEvent | `HANDLE` — signaled when pending items swapped to worker |
| +0xA0 | 4 | shutdownEvent | `HANDLE` — signaled to stop worker thread |
| +0xA4 | 1 | isReady | 1 = worker idle, 0 = worker busy |
| +0xA8 | 0x18 | criticalSection | `CRITICAL_SECTION` (24 bytes on x86) |

## Triple-Buffered Architecture

```
Consumer Thread                     Worker Thread
───────────────                     ─────────────
SubmitRequest(req) ──► [Queue 2]
                        (submission)
                           │
FlushAndCheckCompleted()   │ swap
                           ▼
                       [Queue 1]  ──► WorkerThreadProc
                        (pending)      dequeue → req.Execute()
                                               │
                                               ▼
DequeueCompleted() ◄── [Queue 0]  ◄── enqueue result
                        (completed)
```

The consumer never blocks the worker because submissions go to a separate buffer (Queue 2). `FlushAndCheckCompleted` atomically swaps Queue 2 → Queue 1 when the worker is idle, then signals the worker event.

## IDataThread Vtable (g_DataThread_Vtbl @ 0x10009100)

| Offset | Address | Name | Signature | Description |
|--------|---------|------|-----------|-------------|
| +0x00 | 0x100033F0 | Release | `void(this)` | Calls Dtor, frees memory |
| +0x04 | 0x10001A80 | SetThreadPriority | `BOOL(this, int priority)` | Win32 `SetThreadPriority` on worker |
| +0x08 | 0x10003410 | SetImmediateMode | `void(this, int flag)` | Sets `+0x98` flag |
| +0x0C | 0x10001750 | DequeueCompleted | `ptr(this)` | Pop one from completed queue, returns request ptr or 0 |
| +0x10 | 0x100018B0 | SubmitRequest | `ptr(this, IDataRequest* req)` | Enqueue into submission buffer, returns 0 on success |
| +0x14 | 0x100011E0 | IsReady | `bool(this)` | Returns `+0xA4` (1 = worker idle) |
| +0x18 | 0x10001AC0 | FlushAndCheckCompleted | `bool(this)` | Swap submission→pending, signal worker, return `completedQueue.count > 0` |
| +0x1C | 0x10002290 | FindRequestStatus | `int(this, int idLow, int idHigh)` | Search all 3 queues, return 1/2/3 or 0 |

### Initial Vtable (0x10009120)

All 8 slots point to `0x10003872` (`_purecall`) — confirms `IDataThread` is an abstract base class with pure virtual methods.

## IDataRequest Interface (inferred from usage)

Request objects passed to `SubmitRequest` have their own vtable:

| Offset | Called By | Description |
|--------|-----------|-------------|
| +0x00 | FindRequestStatus | `GetId()` → returns `(idLow, idHigh)` for matching |
| +0x04 | WorkerThreadProc | `Execute()` — called by worker thread to process request |
| +0x08 | SubmitRequest | Status check (if returns 1, request is rejected) |
| +0x0C | Dtor | `Release()` — cleanup/free, called during shutdown |

## Constructor (DataThread_Ctor @ 0x100011F0)

1. Sets initial vtable → `0x10009120` (purecall table)
2. Zero-initializes 3 ring buffer structures (+0x08, +0x38, +0x68, each 0x2C bytes)
3. `InitializeCriticalSection(+0xA8)`
4. Overwrites vtable → `g_DataThread_Vtbl` (0x10009100)
5. Creates `workAvailableEvent` (+0xA0) and `shutdownEvent` (+0x9C)
6. Sets `isReady` (+0xA4) = 1 (actually set as `+0x29` byte via `lpParameter[0x29].b = 1` = byte at +0xA4)
7. Creates worker thread (`CreateThread` with `DataThread_WorkerEntryPoint`), starts suspended, then resumes

## Worker Thread (DataThread_WorkerThreadProc @ 0x10001010)

```
loop:
  WaitForMultipleObjects([shutdownEvent, workAvailableEvent])
  if shutdownEvent → exit
  isReady = 0  (busy)
  EnterCriticalSection
  while pendingQueue.count > 0:
    req = dequeue(pendingQueue)
    req.vtable[+0x04]()        // Execute
    enqueue(completedQueue, req)
  LeaveCriticalSection
  isReady = 1  (idle)
  goto loop
```

## Key Functions

| Address | Name | Description |
|---------|------|-------------|
| 0x10001AA0 | DataThreadCreateNew | Factory: alloc 0xC0 + call Ctor |
| 0x100011F0 | DataThread_Ctor | Constructor |
| 0x10001310 | DataThread_Dtor | Destructor body (signal shutdown, wait, cleanup) |
| 0x10001000 | DataThread_WorkerEntryPoint | Thread entry point (null guard → WorkerThreadProc) |
| 0x10001010 | DataThread_WorkerThreadProc | Main worker loop |

## BNinja Renames Applied

| Address | Old Name | New Name |
|---------|----------|----------|
| 0x10001AA0 | (mangled export) | DataThreadCreateNew |
| 0x100011F0 | sub_100011F0 | DataThread_Ctor |
| 0x10001310 | sub_10001310 | DataThread_Dtor |
| 0x100033F0 | sub_100033F0 | DataThread_Release |
| 0x10001A80 | sub_10001A80 | DataThread_SetThreadPriority |
| 0x10003410 | sub_10003410 | DataThread_SetImmediateMode |
| 0x10001750 | sub_10001750 | DataThread_DequeueCompleted |
| 0x100018B0 | sub_100018B0 | DataThread_SubmitRequest |
| 0x100011E0 | sub_100011E0 | DataThread_IsReady |
| 0x10001AC0 | sub_10001AC0 | DataThread_FlushAndCheckCompleted |
| 0x10002290 | sub_10002290 | DataThread_FindRequestStatus |
| 0x10001010 | sub_10001010 | DataThread_WorkerThreadProc |
| 0x10001000 | sub_10001000 | DataThread_WorkerEntryPoint |
| 0x10009100 | data_10009100 | g_DataThread_Vtbl |
