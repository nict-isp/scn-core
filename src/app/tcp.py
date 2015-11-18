from msgpackrpc.transport import tcp
from tornado.iostream import IOStream

class ClientTransport(tcp.ClientTransport):
    def connect(self):
        stream = IOStream(self._address.socket(), io_loop=self._session._loop._ioloop, max_buffer_size=1024*1024*1024*3)
        socket = tcp.ClientSocket(stream, self, self._encodings)
        socket.connect();

class ServerTransport(tcp.ServerTransport):
    def listen(self, server):
        self._server = server;
        self._mp_server = MessagePackServer(self, io_loop=self._server._loop._ioloop, encodings=self._encodings)
        self._mp_server.listen(self._address.port)

class MessagePackServer(tcp.MessagePackServer):
    def __init__(self, transport, io_loop=None, ssl_options=None, encodings=None):
        if ssl_options is not None:
            raise ValueError('ssl options unsuported.')
        tcp.MessagePackServer.__init__(self, transport, io_loop=io_loop, encodings=encodings)

    def _handle_connection(self, connection, address):
        try:
            stream = IOStream(connection, io_loop=self.io_loop, max_buffer_size=1024*1024*1024*3)
            self.handle_stream(stream, address)
        except Exception:
            logging.error("Error in connection callback", exc_info=True)

