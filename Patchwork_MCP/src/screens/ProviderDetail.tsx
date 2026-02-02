import { Star, MapPin, Shield, Heart, MessageCircle, Calendar } from "lucide-react";
import { useState } from "react";
import { AppBar } from "../components/patchwork/AppBar";
import { Avatar } from "../components/patchwork/Avatar";
import { Badge } from "../components/patchwork/Badge";
import { Button } from "../components/patchwork/Button";
import { Chip } from "../components/patchwork/Chip";
import { Card } from "../components/patchwork/Card";

// Mock data structure for different services
const serviceData = {
  "Plumbing": {
    bio: "Licensed plumber with 12+ years of experience. I specialize in residential and commercial plumbing repairs, installations, and emergency services. Available 7 days a week for urgent issues.",
    pricing: {
      rateType: "hourly",
      hourlyRate: "$85/hr",
      emergency: "$150 flat",
      minimum: "1 hour"
    },
    reviews: [
      { name: "Emily R.", rating: 5, text: "Quick response and professional work. Fixed our leak within an hour!", date: "Oct 28, 2024", service: "Plumbing" },
      { name: "Michael T.", rating: 5, text: "Excellent service. Very knowledgeable and fair pricing.", date: "Oct 15, 2024", service: "Plumbing" },
      { name: "Lisa K.", rating: 4, text: "Good work but arrived 20 min late. Otherwise no complaints.", date: "Oct 3, 2024", service: "Plumbing" }
    ]
  },
  "Pipe Repair": {
    bio: "Expert in pipe repairs and replacements. I've fixed thousands of leaking pipes, burst pipes, and pipe corrosion issues. I use only high-quality materials and provide warranties on all repairs.",
    pricing: {
      rateType: "fixed",
      fixedRate: "$200 per job",
      emergency: "$250 flat",
      warranty: "2 year warranty"
    },
    reviews: [
      { name: "John D.", rating: 5, text: "Fixed my burst pipe quickly and professionally. Great job!", date: "Nov 2, 2024", service: "Pipe Repair" },
      { name: "Sarah M.", rating: 5, text: "Very thorough with the pipe replacement. Clean work area too.", date: "Oct 20, 2024", service: "Pipe Repair" }
    ]
  },
  "Drain Cleaning": {
    bio: "Specialized in drain cleaning and unclogging services. Using professional-grade equipment, I can clear even the toughest blockages. Same-day service available for emergencies.",
    pricing: {
      rateType: "fixed",
      fixedRate: "$120 per drain",
      emergency: "$180 flat",
      camera: "$50 for camera inspection"
    },
    reviews: [
      { name: "Tom W.", rating: 5, text: "Cleared my kitchen drain perfectly. Very efficient!", date: "Nov 5, 2024", service: "Drain Cleaning" },
      { name: "Amy L.", rating: 4, text: "Good service, cleared the blockage completely.", date: "Oct 25, 2024", service: "Drain Cleaning" }
    ]
  },
  "Water Heater": {
    bio: "Certified water heater specialist with expertise in installation, repair, and maintenance of all brands. I can diagnose issues quickly and offer cost-effective solutions.",
    pricing: {
      rateType: "hourly",
      hourlyRate: "$95/hr",
      installation: "$500-1200 (labor only)",
      minimum: "2 hours"
    },
    reviews: [
      { name: "David P.", rating: 5, text: "Installed my new water heater perfectly. Very professional.", date: "Oct 30, 2024", service: "Water Heater" },
      { name: "Rachel S.", rating: 5, text: "Fixed my water heater issue quickly. Great communication.", date: "Oct 12, 2024", service: "Water Heater" }
    ]
  }
};

export function ProviderDetail({ onBack, onNavigate }: { onBack: () => void; onNavigate: (screen: string) => void }) {
  const services = ["Plumbing", "Pipe Repair", "Drain Cleaning", "Water Heater"];
  const [selectedService, setSelectedService] = useState("Plumbing");
  
  const currentData = serviceData[selectedService as keyof typeof serviceData];

  return (
    <div className="min-h-screen bg-neutral-50 pb-24">
      <AppBar onBack={onBack} />

      <div className="bg-white px-4 pt-4 pb-6">
        <div className="flex items-start gap-4 mb-4">
          <Avatar src="" alt="Alex Chen" size="lg" />
          <div className="flex-1">
            <h1 className="text-neutral-900 mb-2">Alex Chen</h1>
            <p className="text-[#6B7280] mb-2">Plumbing Specialist</p>
            <div className="flex items-center gap-3">
              <div className="flex items-center gap-1">
                <Star size={16} className="fill-yellow-400 text-yellow-400" />
                <span>4.9</span>
                <span className="text-[#6B7280]">(127)</span>
              </div>
              <div className="flex items-center gap-1 text-[#6B7280]">
                <MapPin size={16} />
                <span>3.2 km</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="px-4 py-6 space-y-6">
        <div>
          <h2 className="text-neutral-900 mb-3">Services</h2>
          <div className="flex flex-wrap gap-2">
            {services.map((service) => (
              <Chip 
                key={service} 
                label={service} 
                active={selectedService === service}
                onClick={() => setSelectedService(service)} 
              />
            ))}
          </div>
        </div>

        <div>
          <h2 className="text-neutral-900 mb-3">About</h2>
          <p className="text-[#6B7280]">
            {currentData.bio}
          </p>
        </div>

        <div>
          <h2 className="text-neutral-900 mb-3">Pricing</h2>
          <Card>
            <div className="space-y-2">
              {currentData.pricing.rateType === "hourly" && (
                <div className="flex justify-between">
                  <span className="text-[#6B7280]">Hourly rate</span>
                  <span className="text-neutral-900">{currentData.pricing.hourlyRate}</span>
                </div>
              )}
              {currentData.pricing.rateType === "fixed" && (
                <div className="flex justify-between">
                  <span className="text-[#6B7280]">Fixed rate</span>
                  <span className="text-neutral-900">{currentData.pricing.fixedRate}</span>
                </div>
              )}
              <div className="flex justify-between">
                <span className="text-[#6B7280]">Emergency call-out</span>
                <span className="text-neutral-900">{currentData.pricing.emergency}</span>
              </div>
              {currentData.pricing.minimum && (
                <div className="flex justify-between">
                  <span className="text-[#6B7280]">Minimum charge</span>
                  <span className="text-neutral-900">{currentData.pricing.minimum}</span>
                </div>
              )}
              {currentData.pricing.warranty && (
                <div className="flex justify-between">
                  <span className="text-[#6B7280]">Warranty</span>
                  <span className="text-neutral-900">{currentData.pricing.warranty}</span>
                </div>
              )}
              {currentData.pricing.camera && (
                <div className="flex justify-between">
                  <span className="text-[#6B7280]">Camera inspection</span>
                  <span className="text-neutral-900">{currentData.pricing.camera}</span>
                </div>
              )}
              {currentData.pricing.installation && (
                <div className="flex justify-between">
                  <span className="text-[#6B7280]">Installation</span>
                  <span className="text-neutral-900">{currentData.pricing.installation}</span>
                </div>
              )}
            </div>
          </Card>
        </div>

        <div>
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-neutral-900">Reviews</h2>
            <button className="text-[#4F46E5]">See all 127</button>
          </div>

          <div className="bg-white rounded-lg p-4 mb-4">
            <div className="flex gap-2 mb-3">
              {[5, 4, 3, 2, 1].map((stars) => (
                <div key={stars} className="flex-1">
                  <div className="flex items-center gap-1 mb-1">
                    <span className="text-sm">{stars}</span>
                    <Star size={12} className="fill-yellow-400 text-yellow-400" />
                  </div>
                  <div className="h-2 bg-neutral-100 rounded-full overflow-hidden">
                    <div
                      className="h-full bg-yellow-400"
                      style={{ width: stars === 5 ? "85%" : stars === 4 ? "12%" : "3%" }}
                    />
                  </div>
                </div>
              ))}
            </div>
            <p className="text-[#6B7280] text-sm">Only verified clients may review</p>
          </div>

          <div className="space-y-3">
            {currentData.reviews.map((review, i) => (
              <Card key={i}>
                <div className="flex items-start gap-3 mb-2">
                  <Avatar src="" alt={review.name} size="sm" />
                  <div className="flex-1">
                    <div className="flex items-center gap-2 mb-1">
                      <p className="text-neutral-900">{review.name}</p>
                      <Badge variant="success">Verified hire</Badge>
                    </div>
                    <div className="flex items-center gap-2 mb-2">
                      <div className="flex">
                        {Array.from({ length: review.rating }).map((_, i) => (
                          <Star key={i} size={14} className="fill-yellow-400 text-yellow-400" />
                        ))}
                      </div>
                      <span className="text-[#6B7280] text-sm">{review.date}</span>
                    </div>
                    <p className="text-[#6B7280]">{review.text}</p>
                  </div>
                </div>
              </Card>
            ))}
          </div>
        </div>
      </div>

      <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-neutral-200 p-4">
        <div className="max-w-[390px] mx-auto flex gap-3">
          <button className="size-12 border border-neutral-300 rounded-lg flex items-center justify-center">
            <Heart size={20} className="text-neutral-900" />
          </button>
          <Button variant="primary" fullWidth onClick={() => onNavigate("chat")}>
            <div className="flex items-center justify-center gap-2">
              <MessageCircle size={20} />
              <span>Chat</span>
            </div>
          </Button>
        </div>
      </div>
    </div>
  );
}