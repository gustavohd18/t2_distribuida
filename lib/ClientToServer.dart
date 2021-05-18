class ClientToServer {
  final String id;
  final String ip;
  final int availablePort;
  final List<String> files;
  ClientToServer(this.id, this.ip, this.availablePort, this.files);

  ClientToServer.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        ip = json['ip'],
        availablePort = json['availablePort'],
        files = json['files'];

  Map<String, dynamic> toJson() => {
    'id' : id,
    'ip' : ip,
    'availablePort' : availablePort,
    'files' : files,
  };
}
