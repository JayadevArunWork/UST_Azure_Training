import React, { useState } from 'react';
import { askChatbot } from '../services/aiApi';
import { MessageCircle, X } from 'lucide-react';

export default function AIChatbot({ patientId }) {
    const [open, setOpen] = useState(false);
    const [messages, setMessages] = useState([]);
    const [input, setInput] = useState('');
    const [loading, setLoading] = useState(false);

    const handleSend = async () => {
        if (!input.trim()) return;
        const msg = input;
        setMessages(prev => [...prev, { sender: 'user', text: msg }]);
        setInput('');
        setLoading(true);
        try {
            const res = await askChatbot(msg, patientId);
            setMessages(prev => [...prev, { sender: 'bot', text: res.answer }]);
        } catch (err) {
            setMessages(prev => [...prev, { sender: 'bot', text: "Error fetching response." }]);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="fixed bottom-4 right-4 z-50">
            {!open ? (
                <button onClick={() => setOpen(true)} className="p-4 bg-blue-600 text-white rounded-full shadow-lg hover:bg-blue-700">
                    <MessageCircle size={24} />
                </button>
            ) : (
                <div className="bg-white rounded-lg shadow-xl w-80 h-96 flex flex-col overflow-hidden border border-gray-200">
                    <div className="bg-blue-600 text-white p-3 flex justify-between items-center">
                        <h3 className="font-semibold">AI Assistant</h3>
                        <button onClick={() => setOpen(false)}><X size={20} /></button>
                    </div>
                    <div className="flex-1 p-3 overflow-y-auto bg-gray-50 flex flex-col space-y-2">
                        {messages.map((m, i) => (
                            <div key={i} className={`p-2 rounded-lg max-w-[80%] ${m.sender === 'user' ? 'bg-blue-100 self-end text-blue-900' : 'bg-gray-200 self-start text-gray-900'}`}>
                                {m.text}
                            </div>
                        ))}
                        {loading && <div className="text-gray-500 text-sm self-start">Typing...</div>}
                    </div>
                    <div className="p-2 bg-white border-t flex">
                        <input
                            type="text"
                            value={input}
                            onChange={(e) => setInput(e.target.value)}
                            onKeyPress={(e) => e.key === 'Enter' && handleSend()}
                            className="flex-1 border rounded-l-lg p-2 outline-none text-sm"
                            placeholder="Ask me anything..."
                        />
                        <button onClick={handleSend} className="bg-blue-600 text-white px-4 rounded-r-lg hover:bg-blue-700">Send</button>
                    </div>
                </div>
            )}
        </div>
    );
}
