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

class ClientToServer {
  final String id;
  final String ip;
  final int availablePort;
  //files vai ter que ser uma estrutura com hash e name do arquivo um mapa possivelmente
  final List<FileHash> files;
  int time;
  ClientToServer(this.id, this.ip, this.availablePort, this.files, this.time);

  ClientToServer.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        ip = json['ip'],
        availablePort = json['availablePort'],
        files = json['files'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'ip': ip,
        'availablePort': availablePort,
        'files': files,
      };
}
