// class to map messages between client and server using json
class Message {
  final String message;
  final dynamic data;
  Message(this.message, this.data);

  Message.fromJson(Map<String, dynamic> json)
      : message = json['message'],
        data = json['data'];

  Map<String, dynamic> toJson() => {
    'message' : message,
    'data' : data,
  };
}
