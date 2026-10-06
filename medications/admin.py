from django.contrib import admin
from .models import (
    Drug,
    Prescription,
    PrescriptionDrug,
    DrugWarning,
    Remind,
    TakingRecord,
    MedicationHistory,
    PatientAllergy,
)


@admin.register(Drug)
class DrugAdmin(admin.ModelAdmin):
    list_display = ("id", "license", "med_ch", "med_en", "dosage_form", "color", "shape")
    search_fields = ("med_ch", "med_en", "license", "element")
    list_filter = ("dosage_form",)


@admin.register(Prescription)
class PrescriptionAdmin(admin.ModelAdmin):
    list_display = ("prescription_id", "user", "hospital_name", "visit_date")
    search_fields = ("hospital_name", "user__username", "user__user_name")
    list_filter = ("visit_date", "hospital_name")


@admin.register(PrescriptionDrug)
class PrescriptionDrugAdmin(admin.ModelAdmin):
    list_display = ("id", "prescription", "raw_name", "frequency", "days", "total_amount", "remaining_amount", "drug")
    search_fields = ("raw_name", "prescription__hospital_name", "prescription__user__user_name")
    list_filter = ("frequency", "days")


@admin.register(DrugWarning)
class DrugWarningAdmin(admin.ModelAdmin):
    list_display = ("warning_id", "drug", "conflict_target", "warning_desc")
    search_fields = ("drug__med_ch", "conflict_target")


@admin.register(Remind)
class RemindAdmin(admin.ModelAdmin):
    list_display = ("remind_id", "prescription_drug", "frequency_tag", "remind_time", "is_active")
    search_fields = ("prescription_drug__raw_name", "frequency_tag")
    list_filter = ("is_active", "frequency_tag")


@admin.register(TakingRecord)
class TakingRecordAdmin(admin.ModelAdmin):
    list_display = ("takingrecord_id", "remind", "record_date", "taken_at", "status")
    search_fields = ("remind__prescription_drug__raw_name", "status")
    list_filter = ("status", "record_date")


@admin.register(MedicationHistory)
class MedicationHistoryAdmin(admin.ModelAdmin):
    list_display = ("history_id", "user", "drug_name", "drug_code", "dosage", "frequency", "days", "hosp_name", "rx_date", "synced_at")
    search_fields = ("drug_name", "drug_code", "hosp_name", "user__username")
    list_filter = ("hosp_name", "rx_date", "frequency")


@admin.register(PatientAllergy)
class PatientAllergyAdmin(admin.ModelAdmin):
    list_display = ("allergy_id", "user", "allergen_name", "reaction", "synced_at")
    search_fields = ("allergen_name", "user__username")
    list_filter = ("synced_at",)