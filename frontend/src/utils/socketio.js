import io from 'socket.io-client'
const ioManager = new io.Manager('', {
    autoConnect: false
})
export default ioManager