from app.rdocs.mapper import map_rdocs_result
from app.rdocs.provider import DocumentFieldsSnapshot
from tests.conftest import none_snapshot, passport_snapshot


def test_maps_passport_2011_into_form_fields() -> None:
    mapped = map_rdocs_result(passport_snapshot())
    assert mapped.document_type == "russian_passport"
    assert mapped.view == "first_spread"
    assert mapped.error_code is None
    assert mapped.fields["lastName"].value == "ИВАНОВ"
    assert mapped.fields["firstName"].value == "ИВАН"
    assert mapped.fields["middleName"].value == "ИВАНОВИЧ"
    assert mapped.fields["gender"].value == "male"
    assert mapped.fields["birthDate"].value == "01.01.1990"
    assert mapped.fields["issueDate"].value == "15.06.2010"
    assert mapped.fields["series"].value == "1234"
    assert mapped.fields["number"].value == "567890"
    assert mapped.fields["departmentCode"].value == "770-001"
    assert mapped.fields["issuedBy"].value is not None
    assert mapped.fields["birthPlace"].value is not None
    assert mapped.fields["registrationAddress"].value is None
    assert any(item["code"] == "PHOTO_NOT_FOUND" for item in mapped.warnings)
    assert any(item["code"] == "SIGNATURE_NOT_FOUND" for item in mapped.warnings)


def test_licence_number_splits_ten_digits() -> None:
    snapshot = DocumentFieldsSnapshot(
        doctype="INTPASSPORT_1997",
        ocr={"Licence_number": "4500123456", "Last_name_ru": "ПЕТРОВ"},
        quality={"DocConf": 0.8},
    )
    mapped = map_rdocs_result(snapshot)
    assert mapped.fields["series"].value == "4500"
    assert mapped.fields["number"].value == "123456"
    assert mapped.fields["lastName"].value == "ПЕТРОВ"


def test_unknown_doctype_is_not_first_spread() -> None:
    mapped = map_rdocs_result(none_snapshot())
    assert mapped.document_type == "unknown"
    assert mapped.view == "unknown"
    assert mapped.error_code == "NOT_FIRST_SPREAD"
    assert mapped.fields["lastName"].value is None
    assert mapped.fields["series"].value is None


def test_driver_license_is_not_first_spread() -> None:
    mapped = map_rdocs_result(
        DocumentFieldsSnapshot(doctype="DL_2011", ocr={"Last_name_ru": "СИДОРОВ"})
    )
    assert mapped.error_code == "NOT_FIRST_SPREAD"
    assert mapped.fields["lastName"].value is None


def test_maps_registration_address_and_licence() -> None:
    snapshot = DocumentFieldsSnapshot(
        doctype="INTPASSPORTADDR",
        ocr={
            "Address": "Г. МОСКВА\nУЛ. ТВЕРСКАЯ Д. 1",
            "Licence_number": "1234 567890",
        },
        quality={"DocConf": 0.88},
        handwritten_address=False,
    )
    mapped = map_rdocs_result(snapshot, page="registration")
    assert mapped.document_type == "russian_passport"
    assert mapped.view == "registration"
    assert mapped.error_code is None
    assert mapped.fields["registrationAddress"].value == "Г. МОСКВА\nУЛ. ТВЕРСКАЯ Д. 1"
    assert mapped.fields["series"].value is None
    assert mapped.fields["number"].value == "567890"
    assert mapped.fields["lastName"].value is None
    assert not any(item["code"] == "ADDRESS_NOT_RECOGNIZED" for item in mapped.warnings)


def test_handwritten_registration_address_stays_empty() -> None:
    snapshot = DocumentFieldsSnapshot(
        doctype="INTPASSPORTADDR",
        ocr={
            "Address": "Г. МОСКВА\n[рукопись]\nУЛ. ТВЕРСКАЯ Д. 1",
            "Licence_number": "1234 567890",
        },
        quality={"DocConf": 0.88},
        handwritten_address=True,
    )
    mapped = map_rdocs_result(snapshot, page="registration")
    assert mapped.fields["registrationAddress"].value is None
    assert mapped.fields["number"].value == "567890"
    assert any(item["code"] == "ADDRESS_NOT_RECOGNIZED" for item in mapped.warnings)


def test_placeholder_only_registration_address_stays_empty() -> None:
    snapshot = DocumentFieldsSnapshot(
        doctype="INTPASSPORTADDR",
        ocr={"Address": "[рукопись]\n[рукопись]"},
        quality={"DocConf": 0.7},
        handwritten_address=False,
    )
    mapped = map_rdocs_result(snapshot, page="registration")
    assert mapped.fields["registrationAddress"].value is None
    assert any(item["code"] == "ADDRESS_NOT_RECOGNIZED" for item in mapped.warnings)


def test_registration_page_rejects_first_spread() -> None:
    mapped = map_rdocs_result(passport_snapshot(), page="registration")
    assert mapped.error_code == "NOT_REGISTRATION_PAGE"
    assert mapped.fields["registrationAddress"].value is None


def test_registration_as_first_spread_is_rejected() -> None:
    mapped = map_rdocs_result(
        DocumentFieldsSnapshot(doctype="INTPASSPORTADDR", ocr={"Address": "МОСКВА"})
    )
    assert mapped.error_code == "NOT_FIRST_SPREAD"
    assert mapped.fields["registrationAddress"].value is None

