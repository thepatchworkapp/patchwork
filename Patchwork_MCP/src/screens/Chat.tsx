import { Send, Paperclip, Calendar, DollarSign, X, CheckCircle, Clock, Star, Info } from "lucide-react";
import { AppBar } from "../components/patchwork/AppBar";
import { Avatar } from "../components/patchwork/Avatar";
import { Badge } from "../components/patchwork/Badge";
import { Button } from "../components/patchwork/Button";
import { useState } from "react";

interface Message {
  sender: "me" | "them";
  text: string;
  time: string;
  type?: "text" | "proposal";
  proposal?: {
    rate: string;
    rateType: "hourly" | "flat";
    startTime: string;
    notes?: string;
    status: "pending" | "accepted" | "declined" | "completed";
  };
}

import { Id } from "../../convex/_generated/dataModel";

export function Chat({ onBack, conversationId }: { onBack: () => void; conversationId?: Id<"conversations"> }) {
  // For demo purposes, let's say "me" is the Tasker (Alex Chen) and "them" is the Seeker
  const isTasker = true; // In real app, this would come from user context
  
  const [showProposalModal, setShowProposalModal] = useState(false);
  const [showCompleteModal, setShowCompleteModal] = useState(false);
  const [showReviewModal, setShowReviewModal] = useState(false);
  const [counteringProposal, setCounteringProposal] = useState<Message | null>(null);
  const [rating, setRating] = useState(0);
  const [reviewText, setReviewText] = useState("");
  const [proposalRate, setProposalRate] = useState("");
  const [proposalRateType, setProposalRateType] = useState<"hourly" | "flat">("hourly");
  const [proposalStartDate, setProposalStartDate] = useState("");
  const [proposalStartTime, setProposalStartTime] = useState("");
  const [proposalNotes, setProposalNotes] = useState("");
  const [jobStatus, setJobStatus] = useState<"none" | "in-progress">("none");
  const [activeJob, setActiveJob] = useState<any>(null);
  
  const [messages, setMessages] = useState<Message[]>([
    { sender: "them", text: "Hi! I saw your plumbing request. I can help with that.", time: "10:30 AM", type: "text" },
    { sender: "them", text: "I have availability tomorrow afternoon. Would 2pm work?", time: "10:31 AM", type: "text" },
    { sender: "me", text: "Hi Alex! Yes, 2pm tomorrow works great.", time: "10:45 AM", type: "text" },
    { sender: "them", text: "Perfect! My rate is $85/hr and I estimate this will take about 1-2 hours.", time: "10:46 AM", type: "text" },
    { sender: "me", text: "Sounds good. See you tomorrow!", time: "10:50 AM", type: "text" }
  ]);

  const handleSendProposal = () => {
    // Validate inputs
    if (!proposalRate || !proposalStartDate || !proposalStartTime) {
      return;
    }
    
    // If countering, mark the old proposal as declined
    if (counteringProposal && counteringProposal.proposal) {
      const declinedProposal: Message = {
        ...counteringProposal,
        proposal: {
          ...counteringProposal.proposal,
          status: "declined"
        }
      };
      setMessages(messages.map(msg => msg === counteringProposal ? declinedProposal : msg));
    }
    
    // Send proposal logic here
    const newProposal: Message = {
      sender: "me",
      text: "Proposal sent",
      time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      type: "proposal",
      proposal: {
        rate: proposalRate,
        rateType: proposalRateType,
        startTime: `${proposalStartDate}T${proposalStartTime}`,
        notes: proposalNotes,
        status: "pending"
      }
    };
    setMessages([...messages, newProposal]);
    setShowProposalModal(false);
    setCounteringProposal(null);
    setProposalRate("");
    setProposalRateType("hourly");
    setProposalStartDate("");
    setProposalStartTime("");
    setProposalNotes("");
  };

  const handleCounterProposal = (proposal: Message) => {
    if (proposal.proposal) {
      setCounteringProposal(proposal);
      setProposalRate(proposal.proposal.rate);
      setProposalRateType(proposal.proposal.rateType);
      const [date, time] = proposal.proposal.startTime.split('T');
      setProposalStartDate(date);
      setProposalStartTime(time);
      setProposalNotes(proposal.proposal.notes || "");
      setShowProposalModal(true);
    }
  };

  const handleAcceptProposal = (proposal: Message) => {
    if (proposal.proposal) {
      const updatedProposal: Message = {
        ...proposal,
        proposal: {
          ...proposal.proposal,
          status: "accepted"
        }
      };
      setMessages(messages.map(msg => msg === proposal ? updatedProposal : msg));
      setJobStatus("in-progress");
      setActiveJob(updatedProposal);
    }
  };

  const handleDeclineProposal = (proposal: Message) => {
    if (proposal.proposal) {
      const updatedProposal: Message = {
        ...proposal,
        proposal: {
          ...proposal.proposal,
          status: "declined"
        }
      };
      setMessages(messages.map(msg => msg === proposal ? updatedProposal : msg));
    }
  };

  const handleCompleteJob = () => {
    if (activeJob && activeJob.proposal) {
      const updatedProposal: Message = {
        ...activeJob,
        proposal: {
          ...activeJob.proposal,
          status: "completed"
        }
      };
      setMessages(messages.map(msg => msg === activeJob ? updatedProposal : msg));
      setJobStatus("none");
      setActiveJob(null);
      setShowCompleteModal(false);
      setShowReviewModal(true);
    }
  };

  const handleSendReview = () => {
    if (activeJob && activeJob.proposal) {
      const updatedProposal: Message = {
        ...activeJob,
        proposal: {
          ...activeJob.proposal,
          status: "completed"
        }
      };
      setMessages(messages.map(msg => msg === activeJob ? updatedProposal : msg));
      setJobStatus("none");
      setActiveJob(null);
      setShowReviewModal(false);
    }
  };

  return (
    <div className="min-h-screen bg-neutral-50 flex flex-col">
      <AppBar
        onBack={onBack}
        title={
          <div className="flex items-center gap-2">
            <Avatar src="" alt="Alex Chen" size="sm" />
            <div>
              <p className="text-neutral-900">Alex Chen</p>
              <p className="text-[#6B7280] text-xs">Plumbing</p>
            </div>
          </div>
        }
      />

      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-4">
        {jobStatus === "in-progress" && (
          <div className="bg-green-50 rounded-lg p-3 border border-green-200">
            <p className="text-sm text-[#16A34A] text-center">Job in progress</p>
          </div>
        )}

        {messages.map((msg, i) => (
          <div key={i}>
            {msg.type === "proposal" && msg.proposal ? (
              <div className="bg-indigo-50 rounded-lg p-4 border border-indigo-200">
                <div className="text-center mb-3">
                  <p className="text-sm text-[#6B7280] mb-1">
                    {new Date(msg.proposal.startTime).toLocaleDateString()} at {new Date(msg.proposal.startTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                  </p>
                  <p className="text-[#4F46E5]">${msg.proposal.rate}/{msg.proposal.rateType}</p>
                  {msg.proposal.notes && (
                    <p className="text-sm text-[#6B7280] mt-2">{msg.proposal.notes}</p>
                  )}
                </div>

                {msg.proposal.status === "pending" && msg.sender === "them" && (
                  <div className="space-y-2 mt-3">
                    <div className="flex gap-2">
                      <Button variant="secondary" fullWidth onClick={() => handleDeclineProposal(msg)}>
                        Decline
                      </Button>
                      <Button variant="secondary" fullWidth onClick={() => handleCounterProposal(msg)}>
                        Counter
                      </Button>
                      <Button variant="primary" fullWidth onClick={() => handleAcceptProposal(msg)}>
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
              </div>
            ) : (
              <div className={`flex ${msg.sender === "me" ? "justify-end" : "justify-start"}`}>
                <div className={`max-w-[75%] ${msg.sender === "me" ? "order-1" : "order-2"}`}>
                  <div className={`rounded-lg px-4 py-3 ${
                    msg.sender === "me"
                      ? "bg-[#4F46E5] text-white"
                      : "bg-white border border-neutral-200 text-neutral-900"
                  }`}>
                    <p>{msg.text}</p>
                  </div>
                  <p className="text-[#6B7280] text-xs mt-1 px-1">{msg.time}</p>
                </div>
              </div>
            )}
          </div>
        ))}
      </div>

      <div className="border-t border-neutral-200 bg-white p-4">
        {jobStatus === "in-progress" ? (
          <div className="mb-3">
            <button 
              onClick={() => setShowCompleteModal(true)}
              className="px-4 py-2 bg-green-100 text-[#16A34A] rounded-lg flex items-center gap-2 text-sm border border-green-200"
            >
              <CheckCircle size={16} />
              <span>In Progress</span>
            </button>
          </div>
        ) : (
          <div className="flex gap-2 mb-3">
            <button 
              onClick={() => setShowProposalModal(true)}
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
            className="flex-1 px-4 py-3 border border-neutral-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#4F46E5] focus:ring-offset-1"
          />
          <button className="p-3 bg-[#4F46E5] text-white rounded-lg">
            <Send size={20} />
          </button>
        </div>
      </div>

      {/* Proposal Modal */}
      {showProposalModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg shadow-lg w-full max-w-[358px]">
            <div className="flex justify-between items-center p-6 border-b border-neutral-200">
              <h3 className="text-neutral-900">Propose Terms</h3>
              <button className="p-1 text-[#6B7280]" onClick={() => setShowProposalModal(false)}>
                <X size={20} />
              </button>
            </div>
            
            <div className="p-6 space-y-4">
              <div>
                <label className="block text-sm text-[#6B7280] mb-2">Rate Type</label>
                <div className="flex gap-2">
                  <button
                    onClick={() => setProposalRateType("hourly")}
                    className={`flex-1 py-2 px-4 rounded-lg border transition-colors ${
                      proposalRateType === "hourly"
                        ? "bg-[#4F46E5] text-white border-[#4F46E5]"
                        : "bg-white text-neutral-900 border-neutral-300"
                    }`}
                  >
                    Hourly
                  </button>
                  <button
                    onClick={() => setProposalRateType("flat")}
                    className={`flex-1 py-2 px-4 rounded-lg border transition-colors ${
                      proposalRateType === "flat"
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
                    value={proposalRate}
                    onChange={(e) => setProposalRate(e.target.value)}
                    className="w-full pl-10 pr-16 py-3 border border-neutral-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#4F46E5] focus:ring-offset-1"
                  />
                  <span className="absolute right-3 top-1/2 -translate-y-1/2 text-[#6B7280]">
                    {proposalRateType === "hourly" ? "/hr" : ""}
                  </span>
                </div>
              </div>

              <div>
                <label className="block text-sm text-[#6B7280] mb-2">Start Date & Time</label>
                <div className="relative">
                  <Calendar size={20} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#6B7280] pointer-events-none" />
                  <input
                    type="date"
                    value={proposalStartDate}
                    onChange={(e) => setProposalStartDate(e.target.value)}
                    className="w-full pl-10 pr-4 py-3 border border-neutral-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#4F46E5] focus:ring-offset-1 cursor-pointer"
                  />
                </div>
                <div className="relative mt-2">
                  <Clock size={20} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#6B7280] pointer-events-none" />
                  <input
                    type="time"
                    value={proposalStartTime}
                    onChange={(e) => setProposalStartTime(e.target.value)}
                    className="w-full pl-10 pr-4 py-3 border border-neutral-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#4F46E5] focus:ring-offset-1 cursor-pointer"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm text-[#6B7280] mb-2">Notes (optional)</label>
                <textarea
                  placeholder="Add any additional details..."
                  value={proposalNotes}
                  onChange={(e) => setProposalNotes(e.target.value)}
                  rows={3}
                  className="w-full px-4 py-3 border border-neutral-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#4F46E5] focus:ring-offset-1 resize-none"
                />
              </div>
            </div>

            <div className="p-6 border-t border-neutral-200 flex gap-3">
              <Button variant="secondary" fullWidth onClick={() => setShowProposalModal(false)}>
                Cancel
              </Button>
              <Button variant="primary" fullWidth onClick={handleSendProposal}>
                Send Proposal
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* Complete Job Modal */}
      {showCompleteModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg shadow-lg w-full max-w-[358px]">
            <div className="flex justify-between items-center p-6 border-b border-neutral-200">
              <h3 className="text-neutral-900">Complete Job</h3>
              <button className="p-1 text-[#6B7280]" onClick={() => setShowCompleteModal(false)}>
                <X size={20} />
              </button>
            </div>
            
            <div className="p-6 space-y-4">
              <p className="text-sm text-[#6B7280]">Are you sure you want to mark this job as completed?</p>
            </div>

            <div className="p-6 border-t border-neutral-200 flex gap-3">
              <Button variant="secondary" fullWidth onClick={() => setShowCompleteModal(false)}>
                Cancel
              </Button>
              <Button variant="primary" fullWidth onClick={handleCompleteJob}>
                Complete Job
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* Review Modal */}
      {showReviewModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg shadow-lg w-full max-w-[358px] max-h-[90vh] overflow-y-auto">
            <div className="flex justify-between items-center p-6 border-b border-neutral-200">
              <h3 className="text-neutral-900">Review Job</h3>
              <button className="p-1 text-[#6B7280]" onClick={() => setShowReviewModal(false)}>
                <X size={20} />
              </button>
            </div>
            
            <div className="p-6 space-y-4">
              <p className="text-sm text-[#6B7280]">How was your experience with Alex Chen?</p>
              
              {/* Tooltip */}
              <div className="bg-amber-50 border border-amber-200 rounded-lg p-3 flex gap-2">
                <Info size={16} className="text-amber-600 flex-shrink-0 mt-0.5" />
                <p className="text-xs text-amber-800">
                  Only rate once you agree the job has been completed. Feel free to message to tidy up any details first. For major disputes, rate 1 star (job incomplete).
                </p>
              </div>
              
              {/* Star Rating */}
              <div>
                <div className="flex items-center justify-center gap-2 mb-3">
                  {[1, 2, 3, 4, 5].map(star => (
                    <Star
                      key={star}
                      size={32}
                      className={`cursor-pointer transition-colors ${
                        star <= rating ? "text-yellow-400 fill-yellow-400" : "text-neutral-300"
                      }`}
                      onClick={() => setRating(star)}
                    />
                  ))}
                </div>
                
                {/* Rating Description */}
                {rating > 0 && (
                  <p className="text-center text-sm text-[#6B7280]">
                    {rating === 1 && "Job incomplete / Major issue"}
                    {rating === 2 && "Below expectations"}
                    {rating === 3 && "Met expectations"}
                    {rating === 4 && "Above expectations"}
                    {rating === 5 && "Excellent work"}
                  </p>
                )}
              </div>
              
              {/* Review Text */}
              <div>
                <label className="block text-sm text-[#6B7280] mb-2">Your Review</label>
                <textarea
                  placeholder="Share details about your experience..."
                  value={reviewText}
                  onChange={(e) => setReviewText(e.target.value)}
                  rows={4}
                  className="w-full px-4 py-3 border border-neutral-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#4F46E5] focus:ring-offset-1 resize-none"
                />
              </div>
            </div>

            <div className="p-6 border-t border-neutral-200 flex gap-3">
              <Button variant="secondary" fullWidth onClick={() => setShowReviewModal(false)}>
                Skip for Now
              </Button>
              <Button 
                variant="primary" 
                fullWidth 
                onClick={handleSendReview}
                disabled={rating === 0}
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