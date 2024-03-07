# Bisco Foods Holding Corp

Bisco Foods is a large, international conglomarant of food and logisitics companies, based out of St. Louis MI and a member of the G1000. Listed on the NYSE, it is an anchor blue chip stock with stable revenue, but faces headwinds from inflation and global logistics instabality as well as global competition.

As a conglomerant, Bisco Foods is really made up of hundreds of brands and subsidary companies picked up from M&A over the decades. Some of those orgs still maintain their own indepedent back office or supply chain related technology infrastructure.

## Unique Technical Challenges

Bisco foods has all the same problems as any other mature North American enterprise, and manages it's IT purchasing to fall in line with G1000 norms. A recent CTO change brought in a "Everything to the cloud Mandate" roadmap that many established employees believe doesn't reflect the operational reality of the companies infrastructure.

Unique to companies in their space, Bisco has hundreds of stranded, unique and bespoke islands of infrastructure. Examples of this include:

- Livestock and Processing facilities monitoring and operations outside of it's core disciplines
    - In going after it's logistics and existing contracts business, Bisco purchased a regional competitor several years ago that happened to own Livestock Processing and Logistics facilties from it's own previous acquisition. The business is still profitable with minimal need for change or re-investment, so the business is maintaned.
        - This means the IT teams are responsible for supporting these unicorn facilities, with seperate and aging production infrastructure such as Sybase or an ancient SAP stack.
        - These sites are scattered throughout the American South East, where most of the companies large assets are in the Midwest.
- Multiple trucking and logistics hubs
    - Each with it's own seprate operations scopes and teams, non-integrated after multiple M&As
- Legacy on-prem sites still hosting "the brains"
    - While Bisco has been on a project to "modernize" it's core billing and smarts engine, in 2024 it still resides on a Sybase Database on an IBM Power system inside their on-prem facility in St. Louis.
    - It has no DR, and the team trying to modernize it has been unsuccesful in 6 years
- Compliance and Regulation
    - Being in a highly regulated industry with hundreds of brands and subsidaries from M&A, Bisco foods is tightly regulated and has difficulty keeping up with it's compliance burden.
- Number of sites with Human IT services
    - While Bisco tries to consolidate human operations in it's major hubs, it's M&A activity means that small and regional offices persist and must be supported for years afte the initial acquisition. Each of these sites must be incorporated into Bisco's main human management systems and networks.

### Bisco Foods Development Posture

Bisco as a business does not rely heavily on an internally sourced development team or organization for revenues. While some integrations and operations necessitate small pieces of business software, that teams only operates on internally facing systems, and nothing of scale.

For the few outward facing applications or intiatives either directly with consumers or for long running strategic intiatives, Bisco prefers to hire outside development shops and consultation. These relationships are long standing at are local to St. Louis MI.

### Bisco Foods Cloud Posture

Bisco foods is not naturally cloud friendly, traditionally prefering traditionally designed and consumed data center services. The new CTO however, has mandated a "Everything to the Cloud" program targeted at Azure, who is closely sponsoring the project with credits and publicity.

Most of the technical work regarding cloud services is done by management partners or outsourced development teams, leaving Bisco run teams to operate existing traditional infrastructure.

### Bisco Foods Motivations

Bisco C-levels are convinced of their current M&A strategy, and are looking to expand to broader North and South American markets, including Mexico and Brazil.

Bisco IT leadership is strained under the weight of M&A acquisitions, focuses more on day-to-day operations and consolidating / cleaning up stranded systems than trying to implement net new or greenfield projects.


### Bisco Foods Human Drama and Displayed Behavior

Bisco foods is a long running conglomerant with years of M&A history. The executive and IT teams have a variety of factions and allegiances, none of which are aligned.

A common thread amongst the IT teams is a unwillingess to onboard more responsibility for systems that may page or escalate. If it could potentially wake them up to fix it, they don't want to buy it.


### Bisco Foods Legal posture

Bisco Foods runs a large in house legal team for it's core business, but only maintans a small team for sourcing and vendor contracts. Getting a net new legal document through Bisco Foods is a 12+ month process that will involve hours of a seller's legal team to get through.

### Major Infrastructure relationships for Bisco

- Bisco still maintains it's own on-prem facilties and compute, hence it has direct relationships with companies like Liebert and CAT
- Bisco maintains its IBM stack including large IBM Power footprints. It consults with both Accenture and IBM directly on these footprints
- Bisco maintains many, large and complicated VMWare deployments. Some in on-prem / datacenter facilities, some in what are essentially closests trucking warehouses.
- Bisco maintains relationships with nearly every networking vendor, given it's M&A history, it's back-offices contain everything from 14 year old Cisco ASA's to Palo Alto SD-WAN devices
- Bisco maintains a close relationship with the VAR and MSP partner, "St. Louis White Gloves LLC". All non IBM IT purchases go through "St. Louis White Gloves" where possible, and "St. Louis White Gloves" manages much of the sourcing and project management on behalf of Bisco
- Bisco primarily consults with "A+ Design Studios", a St. Louis based web and applications development shop, that does all external facing development work for Bisco and it's related projects and properties.
