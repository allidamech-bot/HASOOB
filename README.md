# Hasoob App

Hasoob App is a comprehensive business management solution designed for small to medium-sized enterprises. It features a robust local-first architecture to ensure reliability and performance, even in offline scenarios.

## Architecture: Local-First Synchronization

The application follows a **local-first** approach. Every data-modifying operation is first committed to a local SQLite database before being enqueued for synchronization with the cloud.

### Key Components

1.  **SQLite Persistence Layer (`DBHelper`)**: Handles all direct data operations on the local device. It is completely decoupled from cloud services to ensure UI responsiveness.
2.  **Sync Queue Service (`SyncQueueService`)**: Manages a persistent queue of pending synchronization operations. It supports smart collapsing (merging redundant updates) and fingerprinting to prevent duplicate syncs.
3.  **Sync Engine (`SyncEngine`)**: The background worker responsible for processing the queue. It handles batching, exponential backoff for network failures, and conflict resolution (defaulting to last-write-wins).
4.  **Sync Manager (`SyncManager`)**: Orchestrates the sync lifecycle, monitors connectivity, and manages user context (Business ID and Firebase UID).

### Data Flow

1.  **User Action**: The user performs an action (e.g., creating an invoice).
2.  **Local Write**: The repository calls `DBHelper` to save the data to SQLite immediately.
3.  **Enqueue**: Upon successful local write, the repository enqueues a `SyncOperation` in the `SyncQueueService`.
4.  **Process**: The `SyncManager` triggers the `SyncEngine` to process the queue.
5.  **Cloud Sync**: The `SyncEngine` pushes the changes to Firebase Firestore.

## Features

-   **Invoice & Quotation Management**: Create, update, and track professional invoices and quotations.
-   **Inventory Tracking**: Real-time stock management with automated inventory adjustments.
-   **Customer Management**: Maintain detailed customer records and statement histories.
-   **Multi-Currency Support**: Handle transactions in multiple currencies with manual override capabilities.
-   **Accounting Integration**: Automated posting to ledgers (Cash, Receivables, Sales, COGS) for every transaction.
-   **Offline Capability**: Full functionality without an internet connection, with seamless background synchronization when connectivity is restored.

## Tech Stack

-   **Frontend**: Flutter
-   **Local Database**: SQLite (`sqflite`)
-   **Backend/Cloud**: Firebase (Firestore, Authentication)
-   **Architecture**: Repository Pattern with Service Decoupling

## Development

### Getting Started

1.  Ensure you have Flutter installed.
2.  Configure Firebase for the project.
3.  Run `flutter pub get` to install dependencies.
4.  Run the app using `flutter run`.

### Testing

The project includes a suite of integration tests for the synchronization logic:
- `test/sync_engine_test.dart`
- `test/sync_manager_test.dart`
- `test/sync_e2e_test.dart`
