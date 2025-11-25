# Lab 08: Architecture Diagrams

## ASCII Architecture Diagram

This diagram shows the complete network security architecture covered in all 5 scenarios:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Lab 08: Network Security Architecture               │
└─────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│ Scenario 1: Network Isolation                                              │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌────────────────────┐                    ┌────────────────────┐          │
│  │   frontend-net     │                    │   backend-net      │          │
│  │                    │                    │                    │          │
│  │  ┌─────────────┐   │                    │  ┌─────────────┐   │          │
│  │  │web-frontend │   │                    │  │web-backend  │   │          │
│  │  └─────────────┘   │                    │  └─────────────┘   │          │
│  │                    │                    │                    │          │
│  │  ┌─────────────┐   │   ┌────────────┐   │                    │          │
│  │  │api-frontend │   │   │api-backend ├── ┼────────────────────┤          │
│  │  └─────────────┘   │   │ (gateway)  │   │                    │          │
│  │                    │   └────────────┘   │                    │          │
│  └────────────────────┘                    └────────────────────┘          │
│                                                                            │
│  Key: Containers on different networks cannot communicate (isolated)       │
│       Gateway containers span multiple networks (controlled access)        │
└────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│ Scenario 2: Multi-Tier Segmentation                                       │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌──────────────┐       ┌──────────────┐       ┌─────────────────┐        │
│  │  public-net  │       │   app-net    │       │  database-net   │        │
│  │  (exposed)   │       │  (internal)  │       │  (most secure)  │        │
│  │              │       │              │       │                 │        │
│  │  ┌────────┐  │       │  ┌────────┐  │       │  ┌──────────┐   │        │
│  │  │  Web   │  │       │  │  App   │  │       │  │ Database │   │        │
│  │  │ (nginx)│◄─┼───────┼─►│ (Flask)│◄─┼───────┼─►│(postgres)│   │        │
│  │  │:8080   │  │       │  │        │  │       │  │          │   │        │
│  │  └────────┘  │       │  └────────┘  │       │  └──────────┘   │        │
│  │              │       │              │       │                 │        │
│  └──────────────┘       └──────────────┘       └─────────────────┘        │
│        ▲                                                                  │
│        │                                                                  │
│    Internet/Host                                                          │
│                                                                           │
│  Security: Web tier CANNOT directly access database tier                  │
│            Forced to go through app tier (logged, monitored)              │
└───────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│ Scenario 3: Internal Networks                                              │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌──────────────┐                      ┌──────────────────────┐            │
│  │   app-net    │                      │  secure-db-net       │            │
│  │  (regular)   │                      │  (internal)          │            │
│  │              │                      │  ╔═══════════════╗   │            │
│  │  ┌────────┐  │                      │  ║ NO GATEWAY    ║   │            │
│  │  │  App   │◄─┼──────────────────────┼─►║               ║   │            │
│  │  │        │  │  Authorized Access   │  ║  ┌──────────┐ ║   │            │
│  │  └────────┘  │                      │  ║  │ Database │ ║   │            │
│  │              │                      │  ║  │          │ ║   │            │
│  └──────────────┘                      │  ║  └──────────┘ ║   │            │
│        ▲                               │  ╚═══════════════╝   │            │
│        │                               │                      │            │
│    Internet                            │  ⚠️  Cannot reach    │            │
│    (can reach)                         │     from outside!    │            │
│                                        └──────────────────────┘            │
│                                                                            │
│  Security: Database has NO external gateway                                │
│            Even -p flag cannot expose it (port binding ignored)            │
│            Perfect for PCI DSS / HIPAA compliance                          │
└────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│ Scenario 4: TLS Encryption                                                 │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌────────────────────────────────────────────────────────┐                │
│  │                    secure-net                          │                │
│  │                                                        │                │
│  │  ┌──────────────┐         🔒 TLS          ┌─────────┐  │                │
│  │  │    Client    │◄──────────────────────► │  nginx  │  │                │
│  │  │  Container   │      encrypted          │  :8443  │  │                │
│  │  │              │                         │         │  │                │
│  │  └──────────────┘                         └─────────┘  │                │
│  │                                                        │                │
│  │  Certificates:                                         │                │
│  │  • CA (self-signed)                                    │                │
│  │  • Server cert + key                                   │                │
│  │  • TLS 1.2/1.3 only                                    │                │
│  │  • Strong ciphers                                      │                │
│  │                                                        │                │
│  └────────────────────────────────────────────────────────┘                │
│        ▲                                                                   │
│        │                                                                   │
│    Host (port 8443)                                                        │
│                                                                            │
│  Security: Traffic encrypted even within Docker network                    │
│            Protects against network sniffing attacks                       │
│            Required for multi-tenant environments                          │
└────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ Scenario 5: Common Misconfigurations                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ❌ BAD: Default Bridge                                                     │
│     docker run nginx    (no DNS, no isolation)                              │
│                                                                             │
│  ❌ BAD: Host Networking                                                    │
│     docker run --network host nginx    (bypasses all security)              │
│                                                                             │
│  ❌ BAD: Exposed Database                                                   │
│     docker run -p 5432:5432 postgres   (attackable from internet)           │
│                                                                             │
│  ❌ BAD: No Resource Limits                                                 │
│     docker run nginx    (can DoS host)                                      │
│                                                                             │
│  ❌ BAD: Running as Root                                                    │
│     (default)           (compromised container = root access)               │
│                                                                             │
│  ❌ BAD: Privileged Mode                                                    │
│     docker run --privileged    (disables ALL security)                      │
│                                                                             │
│  ❌ BAD: Flat Network                                                       │
│     All containers on one network    (no defense in depth)                  │
│                                                                             │
│  ❌ BAD: No Health Checks                                                    │
│     Can't detect crashed apps    (security blind spot)                      │
│                                                                             │
│  ✅ GOOD: See Scenarios 1-4 for proper patterns!                            │
└─────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│ Complete Production Architecture (All Scenarios Combined)                 │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│                          ┌─────────────┐                                  │
│                          │  Internet   │                                  │
│                          └──────┬──────┘                                  │
│                                 │                                         │
│                                 ▼                                         │
│  ┌───────────────────────────────────────────────────────┐                │
│  │                    public-net                         │                │
│  │                                                       │                │
│  │  ┌────────────────────────────────────────────────┐   │                │
│  │  │        Web Tier (nginx)                        │   │                │
│  │  │        • TLS enabled (:8443)                   │   │                │
│  │  │        • Resource limits                       │   │                │
│  │  │        • Health checks                         │   │                │
│  │  │        • Non-root user                         │   │                │
│  │  └──────────────────┬─────────────────────────────┘   │                │
│  └─────────────────────┼─────────────────────────────────┘                │
│                        │                                                  │
│                        ▼                                                  │
│  ┌───────────────────────────────────────────────────────┐                │
│  │                    app-net                            │                │
│  │                                                       │                │
│  │  ┌────────────────────────────────────────────────┐   │                │
│  │  │        App Tier (Flask API)                    │   │                │
│  │  │        • mTLS with web tier                    │   │                │
│  │  │        • Resource limits                       │   │                │
│  │  │        • Health checks                         │   │                │
│  │  │        • Non-root user                         │   │                │
│  │  └──────────────────┬─────────────────────────────┘   │                │
│  └─────────────────────┼─────────────────────────────────┘                │
│                        │                                                  │
│                        ▼                                                  │
│  ┌────────────────────────────────────────────────────────┐               │
│  │              secure-db-net (INTERNAL)                  │               │
│  │              ╔════════════════════════════════════╗    │               │
│  │              ║    Database Tier (PostgreSQL)      ║    │               │
│  │              ║    • Internal network (no gateway) ║    │               │
│  │              ║    • No exposed ports              ║    │               │
│  │              ║    • Resource limits               ║    │               │
│  │              ║    • Health checks                 ║    │               │
│  │              ║    • Non-root user                 ║    │               │
│  │              ╚════════════════════════════════════╝    │               │
│  └────────────────────────────────────────────────────────┘               │
│                                                                           │
│  Security Layers:                                                         │
│  1. Network Isolation (Scenario 1)                                        │
│  2. Multi-Tier Segmentation (Scenario 2)                                  │
│  3. Internal Networks (Scenario 3)                                        │
│  4. TLS Encryption (Scenario 4)                                           │
│  5. Resource Limits, Non-root, Health Checks (Scenario 5)                 │
│                                                                           │
│  Result: Defense in Depth - Multiple layers protect against attacks       │
└───────────────────────────────────────────────────────────────────────────┘
```

## AI-Generated Architecture Diagram Prompt

Use this prompt with DALL-E, Midjourney, or any AI image generator to create a professional architecture diagram:

```
Create a professional technical architecture diagram for Docker Network Security showing:

1. Title: "Docker Network Security - Production Architecture"

2. Three-tier layout (left to right):
   - LEFT: Public Internet cloud symbol with "Internet" label
   - CENTER TOP: "Public Network" zone (light blue) containing:
     * Web tier container (nginx) with port 8443
     * TLS padlock icon
     * Arrow from internet
   - CENTER MIDDLE: "Application Network" zone (light green) containing:
     * App tier container (Flask API)
     * Bidirectional encrypted arrows to web tier
   - CENTER BOTTOM: "Database Network" zone (red) with INTERNAL label containing:
     * Database container (PostgreSQL) 
     * Padlock icon showing it's locked
     * "No External Gateway" warning badge

3. Visual elements:
   - Container icons: Use Docker whale logo or simple rectangles with rounded corners
   - Networks: Show as colored zones/clouds
   - Encryption: Show padlock icons and wavy lines for TLS
   - Isolation: Show red X symbols where connections are blocked
   - Security badges: Green checkmarks for good practices

4. Legend in bottom right:
   - Green checkmark: Secure configuration
   - Red X: Blocked connection
   - Padlock: Encrypted/Internal
   - Wavy line: TLS encryption
   - Dashed line: Internal only

5. Style:
   - Clean, modern, professional
   - Corporate IT style (similar to AWS/Azure diagrams)
   - Colors: Blue for public, Green for app, Red for database
   - White background
   - High contrast for clarity
   - Include subtle shadow effects for depth

6. Annotations:
   - "Defense in Depth" label at top
   - "Network Isolation" pointing to network boundaries
   - "TLS Encryption" pointing to encrypted connections
   - "Internal Network (No Gateway)" pointing to database zone

Make it suitable for technical documentation, presentations, and blog posts.
Resolution: 1920x1080, PNG format with transparency where appropriate.
```

## Alternative Simple Prompt (for quick generation):

```
Professional network architecture diagram showing Docker container security with three tiers: 
public web tier (blue), application tier (green), and internal database tier (red/locked). 
Show TLS encryption between tiers, network isolation, and defense in depth. 
Clean corporate IT style, white background, include legend.
```

## Where to Use These Diagrams

1. **README.md** - Include the ASCII diagram (already works in markdown)
2. **Blog Posts** - Use AI-generated PNG for visual appeal
3. **Presentations** - Professional diagram for slides
4. **Documentation** - Both versions for different audiences
5. **Social Media** - Share the professional diagram on LinkedIn/Twitter

## Diagram Files Location

After generating the AI diagram:
- Save as: `labs/08-network-security/docs/architecture-diagram.png`
- ASCII version is already in this file
- Reference in README with: `![Architecture](docs/architecture-diagram.png)`