import 'package:cbor/cbor.dart';
import 'package:convert/convert.dart';

import 'cose_objects.dart';
import 'mdoc_datastructure.dart';

class DeviceResponse {
  String version;
  List<Document>? documents;
  List<Map<String, int>>? documentErrors;
  int status;

  DeviceResponse(
      {this.version = '1.0',
      this.documents,
      this.documentErrors,
      required this.status});

  /// Parse cbor encoded device response
  ///
  /// [cborData] is allowed to be
  /// - a hex encoded string containing cbor encoded data
  /// - a List<int> of cbor encoded data
  /// - a CborMap
  factory DeviceResponse.fromCbor(dynamic cborData) {
    assert(
        cborData is String || cborData is List<int> || cborData is CborValue);

    var decoded = cborData is CborValue
        ? cborData
        : cborDecode(cborData is String ? hex.decode(cborData) : cborData);
    var asMap = decoded as CborMap;

    var versionTmp = asMap[CborString('version')] as CborString;
    if (versionTmp != CborString('1.0')) {
      throw Exception(
          'Unsupported version $versionTmp. Only version 1.0 is supported');
    }

    var docTmp = asMap[CborString('documents')] as CborList?;
    var docErrorTmp = asMap[CborString('documentErrors')] as CborList?;

    return DeviceResponse(
        documents: docTmp?.map((e) => Document.fromCbor(e)).toList(),
        documentErrors: docErrorTmp
            ?.map((e) => (e as CborMap).map((key, value) => MapEntry(
                (key as CborString).toString(), (value as CborSmallInt).value)))
            .toList(),
        status: (asMap[CborString('status')] as CborSmallInt).value);
  }

  CborMap toCbor() {
    var m = <CborString, CborValue>{CborString('version'): CborString(version)};

    if (documents != null) {
      m[CborString('documents')] =
          CborList(documents!.map((e) => e.toCbor()).toList());
    }

    if (documentErrors != null) {
      m[CborString('documentErrors')] = CborList(documentErrors!
          .map((e) => CborMap(e.map(
              (key, value) => MapEntry(CborString(key), CborSmallInt(value)))))
          .toList());
    }

    m[CborString('status')] = CborSmallInt(status);

    return CborMap(m);
  }

  List<int> toEncodedCbor() {
    return cborEncode(toCbor());
  }

  @override
  String toString() {
    return 'DeviceResponse{version: $version, documents: $documents, documentErrors: $documentErrors, status: $status}';
  }
}

class Document {
  String docType;
  IssuerSignedObject issuerSigned;
  DeviceSignedObject deviceSigned;

  /// {nameSpace : {DataElementIdentifier : ErrorCode}}
  Map<String, Map<String, int>>? errors;

  Document(
      {required this.docType,
      required this.issuerSigned,
      required this.deviceSigned,
      this.errors});

  /// Parse cbor encoded document contained in device response
  ///
  /// [cborData] is allowed to be
  /// - a hex encoded string containing cbor encoded data
  /// - a List<int> of cbor encoded data
  /// - a CborMap
  factory Document.fromCbor(dynamic cborData) {
    assert(
        cborData is String || cborData is List<int> || cborData is CborValue);

    var decoded = cborData is CborValue
        ? cborData
        : cborDecode(cborData is String ? hex.decode(cborData) : cborData);
    var asMap = decoded as CborMap;

    return Document(
        docType: (asMap[CborString('docType')] as CborString).toString(),
        issuerSigned:
            IssuerSignedObject.fromCbor(asMap[CborString('issuerSigned')]),
        deviceSigned:
            DeviceSignedObject.fromCbor(asMap[CborString('deviceSigned')]));
  }

  CborMap toCbor() {
    var m = <CborString, CborValue>{
      CborString('docType'): CborString(docType),
      CborString('issuerSigned'): issuerSigned.toCbor(),
      CborString('deviceSigned'): deviceSigned.toCbor()
    };

    if (errors != null) {
      m[CborString('errors')] = CborMap(errors!.map((key, value) => MapEntry(
          CborString(key),
          CborMap(value.map((key, value) =>
              MapEntry(CborString(key), CborSmallInt(value)))))));
    }

    return CborMap(m);
  }

  List<int> toEncodedCbor() {
    return cborEncode(toCbor());
  }

  @override
  String toString() {
    return 'Document{docType: $docType, issuerSigned: $issuerSigned, deviceSigned: $deviceSigned, errors: $errors}';
  }
}

class DeviceSignedObject {
  ///{nameSpace : {DataElementIdentifier : DataElementValue}}
  Map<String, Map<String, dynamic>> nameSpaces;
  CborBytes nameSpaceBytes;
  CoseSign1? deviceSignature;
  CoseMac0? deviceMac;

  DeviceSignedObject(
      {required this.nameSpaces,
      this.deviceSignature,
      this.deviceMac,
      CborBytes? nameSpaceBytes})
      : nameSpaceBytes = nameSpaceBytes ??
            CborBytes(
                cborEncode(CborMap(nameSpaces.map((key, value) => MapEntry(
                    CborString(key),
                    CborMap(value.map((key, value) =>
                        MapEntry(CborString(key), CborValue(value)))))))),
                tags: [24]);

  /// Parse cbor encoded device signed object
  ///
  /// [cborData] is allowed to be
  /// - a hex encoded string containing cbor encoded data
  /// - a List<int> of cbor encoded data
  /// - a CborMap
  factory DeviceSignedObject.fromCbor(dynamic cborData) {
    assert(
        cborData is String || cborData is List<int> || cborData is CborValue);

    var decoded = cborData is CborValue
        ? cborData
        : cborDecode(cborData is String ? hex.decode(cborData) : cborData);
    var asMap = decoded as CborMap;

    var nameSpacesBytes = asMap[CborString('nameSpaces')] as CborBytes;
    var nameSpacesTmp = cborDecode(nameSpacesBytes.bytes) as CborMap;

    var auth = asMap[CborString('deviceAuth')] as CborMap;
    var macTmp = auth[CborString('deviceMac')] as CborList?;
    var sigTmp = auth[CborString('deviceSignature')] as CborList?;

    return DeviceSignedObject(
        nameSpaces: nameSpacesTmp.isEmpty
            ? {}
            : nameSpacesTmp.map((key, value) => MapEntry(
                (key as CborString).toString(),
                (value as CborMap).map((key, value) => MapEntry(
                    (key as CborString).toString(), value.toObject())))),
        deviceMac: macTmp != null ? CoseMac0.fromCbor(macTmp) : null,
        deviceSignature: sigTmp != null ? CoseSign1.fromCbor(sigTmp) : null,
        nameSpaceBytes: nameSpacesBytes);
  }

  CborMap toCbor() {
    var auth = CborMap({});
    if (deviceMac != null) {
      auth[CborString('deviceMac')] = deviceMac!.toCbor();
    }
    if (deviceSignature != null) {
      auth[CborString('deviceSignature')] = deviceSignature!.toCbor();
    }
    return CborMap({
      CborString('nameSpaces'): nameSpaceBytes,
      CborString('deviceAuth'): auth
    });
  }

  List<int> toEncodedCbor() {
    return cborEncode(toCbor());
  }

  @override
  String toString() {
    return 'DeviceSignedObject{nameSpaces: $nameSpaces, deviceSignature: $deviceSignature, deviceMac: $deviceMac}';
  }
}

class DeviceAuth {
  SessionTranscript sessionTranscript;
  String docType;
  CborBytes nameSpaceBytes;

  DeviceAuth(
      {required this.sessionTranscript,
      required this.docType,
      required this.nameSpaceBytes});

  CborBytes toDeviceAuthBytes() {
    return CborBytes(toEncodedCbor(), tags: [24]);
  }

  CborList toCbor() {
    return CborList([
      CborString('DeviceAuthentication'),
      sessionTranscript.toCbor(),
      CborString(docType),
      nameSpaceBytes
    ]);
  }

  List<int> toEncodedCbor() {
    return cborEncode(toCbor());
  }

  @override
  String toString() {
    return 'DeviceAuth{sessionTranscript: $sessionTranscript, docType: $docType, nameSpaceBytes: $nameSpaceBytes}';
  }
}

class SessionTranscript {
  CborBytes deviceEngagementBytes;
  CborBytes keyBytes;
  Handover? handover;

  SessionTranscript(
      {required this.deviceEngagementBytes,
      required this.keyBytes,
      this.handover});

  /// Parse cbor encoded session transcript
  ///
  /// [cborData] is allowed to be
  /// - a hex encoded string containing cbor encoded data
  /// - a List<int> of cbor encoded data
  /// - a CborList
  /// - CborBytes with tag 24, which means that these bytes are a cbor encoded value
  factory SessionTranscript.fromCbor(dynamic cborData) {
    assert(
        cborData is String || cborData is List<int> || cborData is CborValue);

    var decoded = cborData is CborValue
        ? cborData
        : cborDecode(cborData is String ? hex.decode(cborData) : cborData);

    CborList asList;
    if (decoded.tags.contains(24)) {
      asList = cborDecode((decoded as CborBytes).bytes) as CborList;
    } else {
      asList = decoded as CborList;
    }

    print(asList[2] is CborList);

    return SessionTranscript(
        deviceEngagementBytes: asList.first as CborBytes,
        keyBytes: asList[1] as CborBytes,
        handover:
            asList.last is CborList ? Handover.fromCbor(asList.last) : null);
  }

  CborBytes toSessionTranscriptBytes() {
    return CborBytes(toEncodedCbor(), tags: [24]);
  }

  CborList toCbor() {
    return CborList([
      deviceEngagementBytes,
      keyBytes,
      handover == null ? CborNull() : handover!.toCbor()
    ]);
  }

  List<int> toEncodedCbor() {
    return cborEncode(toCbor());
  }
}

class Handover {
  List<int> handoverSelectMessage;
  List<int>? handoverRequestMessage;

  Handover({required this.handoverSelectMessage, this.handoverRequestMessage});

  /// Parse cbor encoded handover message
  ///
  /// [cborData] is allowed to be
  /// - a hex encoded string containing cbor encoded data
  /// - a List<int> of cbor encoded data
  /// - a CborList
  factory Handover.fromCbor(dynamic cborData) {
    assert(
        cborData is String || cborData is List<int> || cborData is CborValue);

    var decoded = cborData is CborValue
        ? cborData
        : cborDecode(cborData is String ? hex.decode(cborData) : cborData);

    var asList = decoded as CborList;

    return Handover(
        handoverSelectMessage: (asList.first as CborBytes).bytes,
        handoverRequestMessage:
            asList.last is CborBytes ? (asList.last as CborBytes).bytes : null);
  }

  CborList toCbor() {
    return CborList([
      CborBytes(handoverSelectMessage),
      handoverRequestMessage == null
          ? CborNull()
          : CborBytes(handoverRequestMessage!)
    ]);
  }

  List<int> toEncodedCbor() {
    return cborEncode(toCbor());
  }
}

class SessionData {
  int? statusCode;
  List<int>? encryptedData;

  SessionData({this.statusCode, this.encryptedData});

  /// Parse cbor encoded session data
  ///
  /// [cborData] is allowed to be
  /// - a hex encoded string containing cbor encoded data
  /// - a List<int> of cbor encoded data
  /// - a CborMap
  factory SessionData.fromCbor(dynamic cborData) {
    assert(
        cborData is String || cborData is List<int> || cborData is CborValue);

    var decoded = cborData is CborValue
        ? cborData
        : cborDecode(cborData is String ? hex.decode(cborData) : cborData);
    var asMap = decoded as CborMap;

    int? status;
    if (asMap.containsKey(CborString('status'))) {
      status = (asMap[CborString('status')] as CborSmallInt).value;
    }

    List<int>? data;
    if (asMap.containsKey(CborString('data'))) {
      data = (asMap[(CborString('data'))] as CborBytes).bytes;
    }

    return SessionData(statusCode: status, encryptedData: data);
  }

  CborMap toCbor() {
    var toEncode = CborMap({});
    if (encryptedData != null) {
      toEncode[CborString('data')] = CborBytes(encryptedData!);
    }
    if (statusCode != null) {
      toEncode[CborString('status')] = CborSmallInt(statusCode!);
    }
    return toEncode;
  }

  List<int> toEncodedCbor() {
    return cborEncode(toCbor());
  }

  @override
  String toString() {
    return 'SessionData{status: $statusCode, encryptedData: $encryptedData}';
  }
}
