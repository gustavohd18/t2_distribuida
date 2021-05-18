class MessageClient {
  final String message;
  //pode ser qualquer dado ou mapear para somente array de algo
  final dynamic data;
  MessageClient(this.message, this.data);

  MessageClient.fromJson(Map<String, dynamic> json)
      : message = json['message'],
        data = json['data'];

  Map<String, dynamic> toJson() => {
    'message' : message,
    'data' : data,
  };
}
