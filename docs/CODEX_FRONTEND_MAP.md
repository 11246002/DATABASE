# Flutter frontend map

## Entry point and global configuration

- Entry: `app/lib/main.dart::main()` initializes Flutter, attempts `availableCameras()`, then opens `LoginPage`.
- `API_BASE_URL` is hardcoded as `http://172.20.10.4:8000`.
- `cameras` is a global `late List<CameraDescription>`; if camera enumeration throws, it remains uninitialized and opening the scanner can fail.
- All authored app behavior is in the single 2,448-line `main.dart` file.

## Screens and navigation

| Screen | Role | Navigation |
|---|---|---|
| `LoginPage` | Credentials and login | Success replaces with `MainAppPage`; link replaces with `RegisterPage`. |
| `RegisterPage` | Account/health/contact registration | Success dialog replaces with `LoginPage`. |
| `MainAppPage` | Shell with four persistent page instances | Bottom tabs: reminders, medication bag, settings, profile; center FAB pushes scanner. |
| `ScanPrescriptionSheet` | Camera/gallery, crop, OCR confirmation, save/safety result | Custom slide-up route; final result replaces with a fresh `MainAppPage`. |
| `MyMedicationBagPage` | Prescription list, search/sort, create/edit/delete, global safety check | Pushes `PrescriptionDetailPage`. |
| `PrescriptionDetailPage` | Drug details/warnings, add/delete single drug | Returns to bag, which refreshes. |
| `ReminderSettingsPage` | Select prescription, group drugs by frequency, choose times, save reminders | Bottom-tab page. |
| `UserProfilePage` | Read/edit health profile | Bottom-tab page. |
| `AppSettingsPage` | Local switches and placeholder management actions | Bottom-tab page; logout only navigates. |

## State and persistence

- State is widget-local via `setState`; there is no Provider/BLoC/Riverpod/service layer.
- Shared preferences keys: `user_id` (`int`) and `token` (`String`).
- The token is only written. API calls identify the user with `user_id`; no `Authorization` header exists.
- Prescription/reminder/profile state is refetched from the backend; settings switches are neither persisted nor wired to behavior.

## API callers

There are 18 call sites representing 15 unique backend endpoints.

| Widget/function | Method/path | Request and parsing | UI consumer |
|---|---|---|---|
| `_LoginPageState._login` | POST `/accounts/api/login/` | JSON credentials; expects `status`, `message`, `data.user_id`, `data.token`. | Stores preferences and opens main shell. |
| `_RegisterPageState._register` | POST `/accounts/api/register/` | JSON profile fields; treats HTTP 200/201 as success without checking response `status`. | Success/error dialog/snackbar. |
| `_ScanPrescriptionSheetState._uploadAndAnalyze` | POST `/medications/api/scan/` | Multipart `prescription_img`; expects list in `data`. | OCR confirmation dialog. |
| `_checkInteractionsAndSave` | POST `/medications/api/confirm_and_save/` | Multipart `data` JSON plus `prescription_img`; only checks HTTP 200/201. | Immediately runs safety call. |
| `_checkInteractionsAndSave`, `_MyMedicationBagState._checkAllSafety` | POST `/medications/api/check_all_safety/` | JSON `user_id`; expects list with `is_severe_danger` and warning flags. | Red/green dialog or detailed conflicts. |
| `_fetchPrescriptions`, `_fetchUserPrescriptions` | GET `/medications/api/prescriptions/{user_id}/` | Expects prescription list. | Bag list and reminder dropdown. |
| `_createManualPrescription` | POST `/medications/api/prescriptions/create/` | JSON user/hospital/date. | Refreshes bag list. |
| `_updatePrescription` | POST `/medications/api/prescriptions/{id}/update/` | JSON hospital/date. | Refreshes bag list. |
| `_deletePrescription` | POST `/medications/api/prescriptions/{id}/delete/` | No body. | Dismissible removes row optimistically. |
| `_fetchPrescriptionDetails`, `_fetchDrugsForPrescription` | GET `/medications/api/prescription_details/{id}/` | Expects drug list. | Detail cards and reminder grouping. |
| `_addSingleDrug` | POST `/medications/api/prescriptions/{id}/add_drug/` | JSON raw name/frequency/days/total. | Refreshes detail. |
| `_deleteSingleDrug` | POST `/medications/api/prescriptions/drug/{id}/delete/` | No body. | Refreshes detail. |
| `_saveReminders` | POST `/medications/api/reminders/set/` | JSON prescription ID and nested drug/reminder rows. | Snackbar only. |
| `_fetchUserProfile` | POST `/accounts/api/user/profile/` | JSON `user_id`; expects profile `data`. | Profile cards. |
| `_updateProfile` | POST `/accounts/api/user/update/` | JSON `user_id` and editable fields. | Refreshes profile. |

## Image/OCR path

- Gallery uses `image_picker`; camera uses the first enumerated camera.
- Mobile images go through `image_cropper`; web images skip cropping.
- The image is uploaded once for OCR, kept as an `XFile`, and uploaded again with confirmed data for persistence.
- No client-side MIME/size validation or request timeout is configured.

## Major response-use details

- Prescription detail accepts either a list or several guessed wrapper keys, although the backend always returns a list.
- Detail computes `_hasSevereDanger` from a field the detail endpoint does not return, so that flag cannot become true from this response.
- Bag safety first retains any item with any warning, then the dialog filters to actual allergy/drug-conflict flags; informational warnings can create empty list rows.
- Registration's “real name” controller has no backend field. It is only used as a fallback value for `nickname`.
- Deleting a prescription removes the list item before the async result is known and does not restore it on backend failure.

## Incomplete or UI-only behavior

- No group screens use the three group APIs.
- No UI records or shows taking history.
- Reminder rows are stored server-side, but there is no device alarm/notification scheduling implementation.
- Notification and large-font switches are local visual state only.
- “Sync cloud database” and “Export medication record (PDF)” callbacks are empty.
- Logout does not clear shared preferences and there is no backend logout endpoint.

