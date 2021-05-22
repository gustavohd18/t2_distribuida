// class to map data from client's folder
class FilePath {
  final String filename;
  final dynamic path;
  FilePath(this.filename, this.path);

  FilePath.fromJson(Map<String, dynamic> json)
      : filename = json['filename'],
        path = json['path'];

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'path': path,
      };
}
