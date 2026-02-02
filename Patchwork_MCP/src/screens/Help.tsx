import { ChevronRight, Mail, Phone } from "lucide-react";
import { AppBar } from "../components/patchwork/AppBar";
import { Card } from "../components/patchwork/Card";

export function Help({ onBack }: { onBack: () => void }) {
  const faqs = [
    { q: "How accurate is location tracking?", category: "Location" },
    { q: "What if no Taskers are available?", category: "Search" },
    { q: "How do I report a safety concern?", category: "Safety" },
    { q: "Can Taskers pay for better placement?", category: "Reviews" },
    { q: "How are rankings determined?", category: "Reviews" },
    { q: "What if I need to cancel a job?", category: "Jobs" }
  ];

  return (
    <div className="min-h-screen bg-neutral-50">
      <AppBar title="Help & Support" onBack={onBack} />

      <div className="px-4 py-6">
        <h2 className="text-neutral-900 mb-4">Frequently asked questions</h2>
        <div className="space-y-2 mb-8">
          {faqs.map((faq, i) => (
            <Card key={i}>
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-neutral-900 mb-1">{faq.q}</p>
                  <p className="text-[#6B7280] text-sm">{faq.category}</p>
                </div>
                <ChevronRight size={20} className="text-[#6B7280]" />
              </div>
            </Card>
          ))}
        </div>

        <h2 className="text-neutral-900 mb-4">Contact us</h2>
        <div className="space-y-3 mb-8">
          <Card>
            <div className="flex items-center gap-3">
              <div className="size-10 rounded-lg bg-indigo-100 flex items-center justify-center">
                <Mail size={20} className="text-[#4F46E5]" />
              </div>
              <div>
                <p className="text-neutral-900">Email support</p>
                <p className="text-[#6B7280] text-sm">support@patchwork.app</p>
              </div>
            </div>
          </Card>

          <Card>
            <div className="flex items-center gap-3">
              <div className="size-10 rounded-lg bg-indigo-100 flex items-center justify-center">
                <Phone size={20} className="text-[#4F46E5]" />
              </div>
              <div>
                <p className="text-neutral-900">Phone support</p>
                <p className="text-[#6B7280] text-sm">1-800-PATCH-WK</p>
                <p className="text-[#6B7280] text-sm">Mon-Fri, 9 AM - 5 PM ET</p>
              </div>
            </div>
          </Card>
        </div>

        <div className="bg-white rounded-lg p-4">
          <h3 className="text-neutral-900 mb-3">Our ranking promise</h3>
          <p className="text-[#6B7280] text-sm mb-3">
            Patchwork never accepts payment for better placement. Rankings are based solely on:
          </p>
          <ul className="space-y-2 text-[#6B7280] text-sm">
            <li>• Verified client reviews and ratings</li>
            <li>• Proximity to your location</li>
            <li>• Recent activity and response time</li>
            <li>• Completion rate and reliability</li>
          </ul>
        </div>
      </div>
    </div>
  );
}
