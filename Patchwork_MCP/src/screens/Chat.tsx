import { Send, Paperclip, Calendar, DollarSign, X, CheckCircle, Clock, Star, Info, ChevronUp } from "lucide-react";
import { AppBar } from "../components/patchwork/AppBar";
import { Avatar } from "../components/patchwork/Avatar";
import { Button } from "../components/patchwork/Button";
import { useState, useRef, useEffect } from "react";
import { Id } from "../../convex/_generated/dataModel";
import { useChat, Message } from "../hooks/useChat";

interface ChatProps {
  onBack: () => void;
  conversationId: Id<"conversations">;
}

export function Chat({ onBack, conversationId }: ChatProps) {
  const {
    messages,
    isLoading,
    hasMoreMessages,
    sendMessage,
    sendProposal,
    acceptProposal,
    declineProposal,
    counterProposal,
    loadMoreMessages,
    currentUser,
  } = useChat(conversationId);

  const [messageText, setMessageText] = useState("");
  
  const [modals, setModals] = useState({
    proposal: false,
    complete: false,
    review: false,
  });

  const [proposalForm, setProposalForm] = useState({
    rate: "",
    rateType: "hourly" as "hourly" | "flat",
    date: "",
    time: "",
    notes: "",
  });

  const [reviewForm, setReviewForm] = useState({
    rating: 0,
    text: "",
  });

  const [counteringProposal, setCounteringProposal] = useState<Message | null>(null);

  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!isLoading) {
      messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
    }
  }, [messages.length, isLoading]);

  const handleSendMessage = async () => {
    if (!messageText.trim()) return;
    await sendMessage(messageText);
    setMessageText("");
  };

  const handleSendProposal = async () => {
    if (!proposalForm.rate || !proposalForm.date || !proposalForm.time) return;

    const rateInCents = Math.round(parseFloat(proposalForm.rate) * 100);
    const startDateTime = `${proposalForm.date}T${proposalForm.time}`;

    if (counteringProposal && counteringProposal.proposal) {
      await counterProposal(
        counteringProposal.proposal._id,
        rateInCents,
        proposalForm.rateType,
        startDateTime,
        proposalForm.notes
      );
      setCounteringProposal(null);
    } else {
      await sendProposal(
        rateInCents,
        proposalForm.rateType,
        startDateTime,
        proposalForm.notes
      );
    }

    setModals(prev => ({ ...prev, proposal: false }));
    setProposalForm({ rate: "", rateType: "hourly", date: "", time: "", notes: "" });
  };

  const handleOpenCounter = (msg: Message) => {
    if (msg.proposal) {
      setCounteringProposal(msg);
      const startDateTime = new Date(msg.proposal.startDateTime);
      setProposalForm({
        rate: (msg.proposal.rate / 100).toString(),
        rateType: msg.proposal.rateType,
        date: startDateTime.toISOString().split('T')[0],
        time: startDateTime.toTimeString().slice(0, 5),
        notes: msg.proposal.notes || "",
      });
      setModals(prev => ({ ...prev, proposal: true }));
    }
  };

  const activeProposal = messages.find(m => 
    m.proposal?.status === "accepted"
  );
  
  const handleCompleteJob = () => {
    setModals(prev => ({ ...prev, complete: false, review: true }));
  };

  const handleSendReview = () => {
    setModals(prev => ({ ...prev, review: false }));
    setReviewForm({ rating: 0, text: "" });
  };

  const isMe = (senderId: Id<"users">) => currentUser && senderId === currentUser._id;

  return (
    <div className="min-h-screen bg-neutral-50 flex flex-col">
      <AppBar
        onBack={onBack}
        title={
          <div className="flex items-center gap-2">
            <Avatar src="" alt="Chat" size="sm" />
            <div>
              <p className="text-neutral-900">Conversation</p>
            </div>
          </div>
        }
      />

      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-4">
        {hasMoreMessages && (
          <div className="flex justify-center">
            <Button variant="secondary" onClick={loadMoreMessages} className="text-xs py-1 h-auto">
              <ChevronUp size={14} className="mr-1" /> Load older messages
            </Button>
          </div>
        )}

        {isLoading && messages.length === 0 && (
          <div className="text-center text-neutral-400 py-4">Loading messages...</div>
        )}

        {activeProposal && (
          <div className="bg-green-50 rounded-lg p-3 border border-green-200">
            <p className="text-sm text-[#16A34A] text-center">Job in progress</p>
          </div>
        )}

        {messages.map((msg) => (
          <div key={msg._id}>
            {msg.type === "proposal" && msg.proposal ? (
              <div className="bg-indigo-50 rounded-lg p-4 border border-indigo-200">
                <div className="text-center mb-3">
                  <p className="text-sm text-[#6B7280] mb-1">
                    {new Date(msg.proposal.startDateTime).toLocaleDateString()} at {new Date(msg.proposal.startDateTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                  </p>
                  <p className="text-[#4F46E5]">${(msg.proposal.rate / 100).toFixed(2)}/{msg.proposal.rateType}</p>
                  {msg.proposal.notes && (
                    <p className="text-sm text-[#6B7280] mt-2">{msg.proposal.notes}</p>
                  )}
                </div>

                {msg.proposal.status === "pending" && !isMe(msg.senderId) && (
                  <div className="space-y-2 mt-3">
                    <div className="flex gap-2">
                      <Button variant="secondary" fullWidth onClick={() => declineProposal(msg.proposal!._id)}>
                        Decline
                      </Button>
                      <Button variant="secondary" fullWidth onClick={() => handleOpenCounter(msg)}>
                        Counter
                      </Button>
                      <Button variant="primary" fullWidth onClick={() => acceptProposal(msg.proposal!._id)}>
                        Accept
                      </Button>
                    </div>
                  </div>
                )}

                {msg.proposal.status === "accepted" && (
                  <div className="flex items-center justify-center gap-2 mt-3 text-[#16A34A]">
                    <CheckCircle size={20} />
                    <span className="text-sm">Proposal accepted</span>
                  </div>
                )}

                {msg.proposal.status === "declined" && (
                  <div className="text-center mt-3 text-sm text-[#6B7280]">
                    Proposal declined
                  </div>
                )}
                 {msg.proposal.status === "countered" && (
                  <div className="text-center mt-3 text-sm text-[#6B7280]">
                    Proposal countered
                  </div>
                )}
              </div>
            ) : msg.type === "system" ? (
               <div className="text-center text-xs text-neutral-400 my-2 italic">
                  {msg.content}
               </div>
            ) : (
              <div className={`flex ${isMe(msg.senderId) ? "justify-end" : "justify-start"}`}>
                <div className={`max-w-[75%] ${isMe(msg.senderId) ? "order-1" : "order-2"}`}>
                  <div className={`rounded-lg px-4 py-3 ${
                    isMe(msg.senderId)
                      ? "bg-[#4F46E5] text-white"
                      : "bg-white border border-neutral-200 text-neutral-900"
                  }`}>
                    <p>{msg.content}</p>
                  </div>
                  <p className="text-[#6B7280] text-xs mt-1 px-1">
                    {new Date(msg.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                  </p>
                </div>
              </div>
            )}
          </div>
        ))}
        <div ref={messagesEndRef} />
      </div>

      <div className="border-t border-neutral-200 bg-white p-4">
        {activeProposal ? (
          <div className="mb-3">
            <button 
              onClick={() => setModals(prev => ({ ...prev, complete: true }))}
              className="px-4 py-2 bg-green-100 text-[#16A34A] rounded-lg flex items-center gap-2 text-sm border border-green-200 w-full justify-center"
            >
              <CheckCircle size={16} />
              <span>Complete Job</span>
            </button>
          </div>
        ) : (
          <div className="flex gap-2 mb-3">
            <button 
              onClick={() => {
                setCounteringProposal(null);
                setProposalForm({ rate: "", rateType: "hourly", date: "", time: "", notes: "" });
                setModals(prev => ({ ...prev, proposal: true }));
              }}
              className="px-3 py-2 bg-neutral-100 text-neutral-900 rounded-lg flex items-center gap-2 text-sm"
            >
              <DollarSign size={16} />
              <span>Propose terms</span>
            </button>
          </div>
        )}

        <div className="flex items-center gap-2">
          <button className="p-2 text-[#6B7280]">
            <Paperclip size={20} />
          </button>
          <input
            type="text"
            placeholder="Type a message..."
            value={messageText}
            onChange={(e) => setMessageText(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && handleSendMessage()}
            className="flex-1 px-4 py-3 border border-neutral-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#4F46E5] focus:ring-offset-1"
          />
          <button 
            onClick={handleSendMessage}
            className="p-3 bg-[#4F46E5] text-white rounded-lg disabled:opacity-50"
            disabled={!messageText.trim()}
          >
            <Send size={20} />
          </button>
        </div>
      </div>

      {modals.proposal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg shadow-lg w-full max-w-[358px]">
            <div className="flex justify-between items-center p-6 border-b border-neutral-200">
              <h3 className="text-neutral-900">{counteringProposal ? "Counter Proposal" : "Propose Terms"}</h3>
              <button className="p-1 text-[#6B7280]" onClick={() => setModals(prev => ({ ...prev, proposal: false }))}>
                <X size={20} />
              </button>
            </div>
            
            <div className="p-6 space-y-4">
              <div>
                <label className="block text-sm text-[#6B7280] mb-2">Rate Type</label>
                <div className="flex gap-2">
                  <button
                    onClick={() => setProposalForm(prev => ({ ...prev, rateType: "hourly" }))}
                    className={`flex-1 py-2 px-4 rounded-lg border transition-colors ${
                      proposalForm.rateType === "hourly"
                        ? "bg-[#4F46E5] text-white border-[#4F46E5]"
                        : "bg-white text-neutral-900 border-neutral-300"
                    }`}
                  >
                    Hourly
                  </button>
                  <button
                    onClick={() => setProposalForm(prev => ({ ...prev, rateType: "flat" }))}
                    className={`flex-1 py-2 px-4 rounded-lg border transition-colors ${
                      proposalForm.rateType === "flat"
                        ? "bg-[#4F46E5] text-white border-[#4F46E5]"
                        : "bg-white text-neutral-900 border-neutral-300"
                    }`}
                  >
                    Flat Rate
                  </button>
                </div>
              </div>

              <div>
                <label className="block text-sm text-[#6B7280] mb-2">Rate</label>
                <div className="relative">
                  <DollarSign size={20} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#6B7280]" />
                  <input
                    type="number"
                    placeholder="85"
                    value={proposalForm.rate}
                    onChange={(e) => setProposalForm(prev => ({ ...prev, rate: e.target.value }))}
                    className="w-full pl-10 pr-16 py-3 border border-neutral-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#4F46E5] focus:ring-offset-1"
                  />
                  <span className="absolute right-3 top-1/2 -translate-y-1/2 text-[#6B7280]">
                    {proposalForm.rateType === "hourly" ? "/hr" : ""}
                  </span>
                </div>
              </div>

              <div>
                <label className="block text-sm text-[#6B7280] mb-2">Start Date & Time</label>
                <div className="relative">
                  <Calendar size={20} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#6B7280] pointer-events-none" />
                  <input
                    type="date"
                    value={proposalForm.date}
                    onChange={(e) => setProposalForm(prev => ({ ...prev, date: e.target.value }))}
                    className="w-full pl-10 pr-4 py-3 border border-neutral-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#4F46E5] focus:ring-offset-1 cursor-pointer"
                  />
                </div>
                <div className="relative mt-2">
                  <Clock size={20} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#6B7280] pointer-events-none" />
                  <input
                    type="time"
                    value={proposalForm.time}
                    onChange={(e) => setProposalForm(prev => ({ ...prev, time: e.target.value }))}
                    className="w-full pl-10 pr-4 py-3 border border-neutral-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#4F46E5] focus:ring-offset-1 cursor-pointer"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm text-[#6B7280] mb-2">Notes (optional)</label>
                <textarea
                  placeholder="Add any additional details..."
                  value={proposalForm.notes}
                  onChange={(e) => setProposalForm(prev => ({ ...prev, notes: e.target.value }))}
                  rows={3}
                  className="w-full px-4 py-3 border border-neutral-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#4F46E5] focus:ring-offset-1 resize-none"
                />
              </div>
            </div>

            <div className="p-6 border-t border-neutral-200 flex gap-3">
              <Button variant="secondary" fullWidth onClick={() => setModals(prev => ({ ...prev, proposal: false }))}>
                Cancel
              </Button>
              <Button variant="primary" fullWidth onClick={handleSendProposal}>
                {counteringProposal ? "Send Counter" : "Send Proposal"}
              </Button>
            </div>
          </div>
        </div>
      )}

      {modals.complete && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg shadow-lg w-full max-w-[358px]">
            <div className="flex justify-between items-center p-6 border-b border-neutral-200">
              <h3 className="text-neutral-900">Complete Job</h3>
              <button className="p-1 text-[#6B7280]" onClick={() => setModals(prev => ({ ...prev, complete: false }))}>
                <X size={20} />
              </button>
            </div>
            
            <div className="p-6 space-y-4">
              <p className="text-sm text-[#6B7280]">Are you sure you want to mark this job as completed?</p>
            </div>

            <div className="p-6 border-t border-neutral-200 flex gap-3">
              <Button variant="secondary" fullWidth onClick={() => setModals(prev => ({ ...prev, complete: false }))}>
                Cancel
              </Button>
              <Button variant="primary" fullWidth onClick={handleCompleteJob}>
                Complete Job
              </Button>
            </div>
          </div>
        </div>
      )}

      {modals.review && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg shadow-lg w-full max-w-[358px] max-h-[90vh] overflow-y-auto">
            <div className="flex justify-between items-center p-6 border-b border-neutral-200">
              <h3 className="text-neutral-900">Review Job</h3>
              <button className="p-1 text-[#6B7280]" onClick={() => setModals(prev => ({ ...prev, review: false }))}>
                <X size={20} />
              </button>
            </div>
            
            <div className="p-6 space-y-4">
              <p className="text-sm text-[#6B7280]">How was your experience?</p>
              
              <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 flex gap-2">
                <Info size={16} className="text-amber-600 flex-shrink-0 mt-0.5" />
                <p className="text-xs text-amber-800">
                  Only rate once you agree the job has been completed.
                </p>
              </div>
              
              <div>
                <div className="flex items-center justify-center gap-2 mb-3">
                  {[1, 2, 3, 4, 5].map(star => (
                    <Star
                      key={star}
                      size={32}
                      className={`cursor-pointer transition-colors ${
                        star <= reviewForm.rating ? "text-yellow-400 fill-yellow-400" : "text-neutral-300"
                      }`}
                      onClick={() => setReviewForm(prev => ({ ...prev, rating: star }))}
                    />
                  ))}
                </div>
              </div>
              
              <div>
                <label className="block text-sm text-[#6B7280] mb-2">Your Review</label>
                <textarea
                  placeholder="Share details about your experience..."
                  value={reviewForm.text}
                  onChange={(e) => setReviewForm(prev => ({ ...prev, text: e.target.value }))}
                  rows={4}
                  className="w-full px-4 py-3 border border-neutral-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#4F46E5] focus:ring-offset-1 resize-none"
                />
              </div>
            </div>

            <div className="p-6 border-t border-neutral-200 flex gap-3">
              <Button variant="secondary" fullWidth onClick={() => setModals(prev => ({ ...prev, review: false }))}>
                Skip for Now
              </Button>
              <Button 
                variant="primary" 
                fullWidth 
                onClick={handleSendReview}
                disabled={reviewForm.rating === 0}
              >
                Submit Review
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
