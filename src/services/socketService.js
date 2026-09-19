/**
 * WebSocket Service using Socket.IO
 */

let io;

const init = (server) => {
    const { Server } = require('socket.io');
    io = new Server(server, {
        cors: {
            origin: "*",
            methods: ["GET", "POST"]
        }
    });

    io.on('connection', (socket) => {
        console.log('Client connected to WebSocket:', socket.id);
        socket.on('disconnect', () => {
            console.log('Client disconnected');
        });
    });

    return io;
};

const emitEvent = (event, payload) => {
    if (io) {
        io.emit(event, payload);
        console.log(`Event ${event} emitted via WebSocket`);
    }
};

module.exports = { init, emitEvent };
