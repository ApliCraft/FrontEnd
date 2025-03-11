import 'package:socket_io_client/socket_io_client.dart' as IO;

main() {
  // Dart client
  IO.Socket socket = IO.io('http://localhost:4000');
  socket.onConnect((_) {
    print('connect');
    socket.emit('ask', {
        message: "wybrana wiadomosc przez filipa"
    });
  });
  socket.on('response', (data) => print(data));
  socket.onDisconnect((_) => print('disconnect'));
  socket.on('fromServer', (_) => print(_));
}
