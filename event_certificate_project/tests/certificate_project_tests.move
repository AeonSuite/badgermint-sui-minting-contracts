#[test_only]
module certificate_project::certificate_project_tests;
use certificate_project::certificate_project;
use sui::test_scenario;

#[error(code = 0)]
const ENotImplemented: vector<u8> = b"Not Implemented";

#[test]
fun test_certificate_project() {
    let mut scenario = test_scenario::begin(@0xA);
    let recipient = @0xB;
    let title = b"Test Title";
    let issuer = b"Test Issuer";
    let issued_date = 0;
    let expiry_date = 0;
    let description = b"Test Description";
    let metadata = b"{\"hello\":\"world\",\"recipient\":\"Test Participant\"}";

    certificate_project::mint_certificate(
        recipient,
        std::string::utf8(title),
        std::string::utf8(issuer),
        issued_date,
        expiry_date,
        std::string::utf8(description),
        metadata,
        test_scenario::ctx(&mut scenario)
    );

    test_scenario::end(scenario);
}

#[test, expected_failure(abort_code = ::certificate_project::certificate_project_tests::ENotImplemented)]
fun test_certificate_project_fail() {
    abort ENotImplemented
}

