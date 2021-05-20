class ClientToServer {
  final String id;
  final String ip;
  final int availablePort;
  final List<String> files;
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
