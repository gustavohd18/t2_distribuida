// class to map hash and filename from client to Server 
class FileHash {
  final String fileName;
  final String hash;
  FileHash(this.fileName, this.hash);

  FileHash.fromJson(Map<String, dynamic> json)
      : fileName = json['filename'],
        hash = json['hash'];

  Map<String, dynamic> toJson() => {
        'filename': fileName,
        'hash': hash,
      };
}
