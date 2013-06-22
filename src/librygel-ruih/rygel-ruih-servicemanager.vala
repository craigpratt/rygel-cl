 /*
 * Rygel is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 /* the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Author: Cablelabs
 
 * Rygel is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

using GUPnP;
using Gee;
using Xml;
using GLib;

public class Rygel.RuihServiceManager
{
    protected static string UI            = "ui";
    protected static string UIID          = "uiID";
    protected static string UILIST        = "uilist";
    protected static string NAME          = "name";
    protected static string DESCRIPTION   = "description";
    protected static string ICONLIST      = "iconList";
    protected static string ICON          = "icon";
    protected static string FORK          = "fork";
    protected static string LIFETIME      = "lifetime";
    protected static string PROTOCOL      = "protocol";
    protected static string DEVICEPROFILE = "deviceprofile";
    protected static string PROTOCOL_INFO   = "protocolInfo";
    protected static string URI             = "uri";
    protected static string SHORT_NAME      = "shortName";
  
    private static string PRE_RESULT =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        + "<" + UILIST + " xmlns=\"urn:schemas-upnp-org:remoteui:uilist-1-0\" "
        + "xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" "
        + "xsi:schemaLocation=\"urn:schemas-upnp-org:remoteui:uilist-1-0 CompatibleUIs.xsd\">\n";
    
    private static string POST_RESULT = "</" + UILIST + ">\n";
    private ArrayList<UIElem> m_uiList;
    protected ArrayList<FilterEntry> filterEntries;
    private static ArrayList<UIElem> oldList;
    protected static bool protoPresent = false;
    public void setUIList(string uiList) throws GLib.Error //synchronized??
    {
        this.m_uiList = new ArrayList<UIElem> ();
        // Empty internal data
        if(uiList == null)
        {
            m_uiList = null;
            return;
        }
       
        Xml.Doc* doc = Parser.parse_file(uiList);
        Xml.Node* uiListNode = doc->get_root_element();
        if(uiListNode != null && 
            UILIST == uiListNode->name)
        {
            for (Xml.Node* childNode = uiListNode->children; childNode != null; childNode = childNode->next)
            {
                if(UI == childNode->name)
                {
                    this.m_uiList.add(new UIElem(childNode));
                }
            }
         }
         oldList = m_uiList;
    }

    public string getCompatibleUIs(string xmlStr, string deviceInfo, string filter) //no synchronized?
    {
        Xml.Node* deviceProfileNode = null;
        ArrayList<ProtocolElem> protocols = new ArrayList<ProtocolElem> ();
        this.filterEntries = new ArrayList<FilterEntry> ();
        File file = null;
        // Parse if there is device info
        if(deviceInfo != null && deviceInfo.length > 0)
        {
            try
            {
                Xml.Doc* doc = null; 
                file = File.new_for_path(deviceInfo);
                var file_info = file.query_info ("*", FileQueryInfoFlags.NONE);
                if (file_info.get_size() != 0)
                {
                    doc = Parser.parse_file(deviceInfo);
                    if (doc == null)
                    {
                        // Cleanup when Bad XML document provided.
                        try
                        {
                            file.trash();
                        }
                        catch (GLib.Error e)
                        {
                            stdout.printf("Error while deleting XML deviceProfile file\n");
                        }
                        error ("Error 706-Type mismatch. Failed to parse XML document.");
                    }
                    deviceProfileNode = doc->get_root_element();
                }
            }
            catch (GLib.Error e)
            {
                stdout.printf("getCompatibleUI's threw an error while doing File I/:O%s\n", e.message);
            }
        }

        // If inputDeviceProfile and filter are empty
        // just display all HTML5 UI elements.
        if(deviceProfileNode == null && filter == "")
        {
            filterEntries.add(new FilterEntry(SHORT_NAME, "*HTML5*"));
        }

        // Parse device info to create protocols
        if(deviceProfileNode != null)
        {
            if(deviceProfileNode != null && 
                    DEVICEPROFILE == deviceProfileNode->name)
            {
                for (Xml.Node* childNode = deviceProfileNode->children; childNode != null; childNode = childNode->next)
                {
                    if(PROTOCOL == childNode->name)
                    {
                        // Get shortName attribute
                        for (Xml.Attr* prop = childNode->properties; prop != null; prop = prop->next) 
                        {
                            if (prop->name == SHORT_NAME)
                            {
                                filterEntries.add(new FilterEntry(SHORT_NAME, prop->children->content));
                            }
                        }
                        try
                        {
                            protocols.add(new ProtocolElem(childNode));
                            filterEntries.add(new FilterEntry(PROTOCOL, childNode->content));
                        }
                        catch (GLib.Error e)
                        {
                            stdout.printf("getCompatibleUI's threw an error %s\n", e.message);
                        }
                    }    
                    if(PROTOCOL_INFO == childNode->name)
                    {
                        filterEntries.add(new FilterEntry(PROTOCOL_INFO, childNode->content));
                    }                
                }//for
            }//if
        } //outer if

        string[] entries = {};
        if (filter.length > 0)
        {
            if(filter == "*" || filter == "\"*\"")
            {
                // Wildcard filter entry
                filterEntries.add(new WildCardFilterEntry());
            }
            else
            {
                // Check if the input UIFilter is in the right format.
                if (filter.get_char(0) != '"' || filter.get_char(filter.length - 1) != '"'
                    ||  (!(filter.contains(",")) && filter.contains(";")))
                {
                    //Cleanup
                    try
                    {
                        file.trash();
                    }
                    catch (GLib.Error e)
                    {
                        stdout.printf("Error while deleting XML deviceProfile file\n");
                    }
                    error ("Error 702-Bad Filter.");
                }

                entries = filter.split(",");
                foreach (unowned string str in entries) 
                {
                    string value = null;
                    // string off quotes
                    var nameValue = str.split("=");
                    if (nameValue != null &&
                        nameValue.length == 2 &&
                        nameValue[1] != null && 
                        nameValue[1].length > 2)
                    {
                        if(nameValue[1].get_char(0) == '"' &&
                           nameValue[1].get_char(nameValue[1].length - 1) == '"')
                        {
                            value = nameValue[1].substring(1, nameValue[1].length - 1);
                            filterEntries.add(new FilterEntry(nameValue[0], value));
                        }
                    }
                }
            }
        }
        // Generate result XML with or without protocols       
        StringBuilder result = new StringBuilder(PRE_RESULT);
        
        if(m_uiList != null && m_uiList.size > 0)
        {
            foreach (UIElem i in m_uiList)
            {
                UIElem ui = (UIElem)i;
                if(ui.match(protocols , filterEntries))
                {
                    result.append(ui.toUIListing(filterEntries));
                }
            }
        }
        result.append(POST_RESULT);
        return result.str; 
    }
   
    protected class FilterEntry
    {

        string m_name = null;
        string m_value = null;
        
        public FilterEntry(string name, string value)
        {
            if (name != null)
            {
                m_name = name;
            }
            if (value != null)
            {
                m_value = value;
            }
        }
        
        public bool matches(string name, string value)
        {
            if(m_name != null && m_value != null)
            {
                string value1 = null;
                // Get rid of extra " left in m_value
                while (m_value.contains("\""))
                {
                    value1 = m_value.replace("\"", "");
                    m_value = value1;
                }

                // Get rid of any * left
                if (m_value.length > 1)
                {
                    while (m_value.contains("*"))
                    {
                        value1 = m_value.replace("*", "");
                        m_value = value1;
                    }
                }
                // Get rid of extra " left in m_name
                while (m_name.contains("\""))
                {
                    value1 = m_name.replace("\"", "");
                    m_name = value1;
                }

                if(m_name == name || m_name == "*") // Wildcard entry "*"
                {
                    if(m_value != null)
                    {
                        if (m_name == LIFETIME)
                        {
                            if(int.parse(m_value) == int.parse(value))
                            {
                                return true;
                            }
                            else
                            {
                                return false;
                            }
                        }     
                        if((m_value == "*") || (m_value == value) || value.contains(m_value)) // Wildcard entry "*"
                        {
                            return true;
                        }
                    }
                }
            }
            return false;
        }
    }
    
    protected class WildCardFilterEntry : FilterEntry 
    {
        public WildCardFilterEntry()
        {
            base("*","*");
        }
       
        public new bool matches(string name, string value)
        {
            return true;
        }
    }

    // Convenience method to avoid a lot of inline loops
    private static bool filtersMatch(Gee.ArrayList<FilterEntry> filters, string name, string value)
    {
        if(filters != null && name != null && value != null)
        {
            foreach (FilterEntry fil in filters)
            {
                FilterEntry entry = (FilterEntry)fil;
                
                if((entry != null) && (entry.matches(name, value)))
                {
                    return true;
                }
            }
        }
        return false;
    }
    
    public abstract class UIListing
    {
        public abstract bool match(Gee.ArrayList<ProtocolElem> protocols, Gee.ArrayList<FilterEntry> filters);
        public abstract string toUIListing(Gee.ArrayList<FilterEntry> filters);
    }

    protected class IconElem : UIListing
    {
        // final???
        private string m_mimeType = null;
        private string m_width = null;
        private string m_height = null;
        private string m_depth = null;
        private string m_url = null;
        private static string MIMETYPE    = "mimetype";
        private static string WIDTH       = "width";
        private static string HEIGHT      = "height";
        private static string DEPTH       = "depth";
        private static string URL         = "url";
        
        public IconElem(Xml.Node* node) throws GLib.Error
        {
            if(node == null)
            {
                // temporary GLib error
                throw new GLib.Error(0, 0, "Node is Null");
            }
            // Invalid XML Handling? 
            for (Xml.Node* childNode = node->children; childNode != null; childNode = childNode->next)
            {
                string nodeName = childNode->name;
                if(MIMETYPE == nodeName)
                {
                    m_mimeType = childNode->get_content();
                }
                else if (WIDTH == nodeName)
                {
                    m_width = childNode->get_content();
                }
                else if (HEIGHT == nodeName)
                {
                    m_height = childNode->get_content();
                }
                else if (DEPTH == nodeName)
                {
                    m_depth = childNode->get_content();
                }
                else if (URL == nodeName)
                {
                    m_url = childNode->get_content();
                }
                else
                {
                    throw new GLib.Error(0, 0, "Bad XML Icon Element");
                }
            }
        }

        public override bool match(Gee.ArrayList<ProtocolElem> protocols, Gee.ArrayList<FilterEntry> filters)
        {
            return true;
        }

        public override string toUIListing(Gee.ArrayList<FilterEntry> filters)
        {
            StringBuilder sb = new StringBuilder();
            bool atleastOne = false;

            XMLFragment elements = new XMLFragment();
            if((m_mimeType != null) && (filtersMatch(filters, ICON + "@" + MIMETYPE, m_mimeType)))
            {
                elements.addElement(MIMETYPE, m_mimeType);
                atleastOne = true;
            }
            if((m_width != null) && (filtersMatch(filters, ICON + "@" + WIDTH, m_width)))
            {
                elements.addElement(WIDTH, m_width);
                atleastOne = true;
            }
            if((m_height != null) && (filtersMatch(filters, ICON + "@" + HEIGHT, m_height)))
            {
                elements.addElement(HEIGHT, m_height);
                atleastOne = true;
            }
            if((m_depth != null) && (filtersMatch(filters, ICON + "@" + DEPTH, m_depth)))
            {
                elements.addElement(DEPTH, m_depth);
                atleastOne = true;
            }
            if((m_url != null) && (filtersMatch(filters, ICON + "@" + URL, m_url)))
            {
                elements.addElement(URL, m_url);
                atleastOne = true;
            }
            
            if(elements.size() > 0)
            {
                sb.append("<" + ICON + ">\n");
                sb.append(elements.toXML());
                sb.append("</" + ICON + ">\n");
            }
            
            if (atleastOne == true)
            {
                return sb.str;
            }
            else
            {
                return "";
            }
        }

    }

    protected class ProtocolElem : UIListing
    {
        private string m_shortName = null;
        private string m_protocolInfo = null;
        private Gee.ArrayList<string> m_uris;
        
        public ProtocolElem(Xml.Node* node) throws GLib.Error
        {
            this.m_uris = new ArrayList<string>();
            if(node == null)
            {
                throw new GLib.Error(0, 0, "Node is Null");
            }
            
            // Get shortName attribute
            for (Xml.Attr* prop = node->properties; prop != null; prop = prop->next) 
            {
                string attr_name = prop->name;
                if (attr_name == SHORT_NAME)
                {
                    m_shortName = prop->children->content;
                    break;
                }
            }
            
            for (Xml.Node* childNode = node->children; childNode != null; childNode = childNode->next)
            {
                string nodeName = childNode->name;
                if(URI == nodeName)
                {
                    m_uris.add(childNode->get_content());
                }
                else if (PROTOCOL_INFO == childNode->name)
                {
                    m_protocolInfo = childNode->get_content();
                }
            }
        }
        
        public string getShortName()
        {
            return m_shortName;
        }
        
        public string getProtocolInfo()
        {
            return m_protocolInfo;
        }

        public override bool match(Gee.ArrayList<ProtocolElem> protocols, Gee.ArrayList filters)
        {
            bool result = false;
            if(protocols == null || protocols.size == 0)
            {
                return true;
            }

            foreach (ProtocolElem i in protocols)
            {
                ProtocolElem proto = (ProtocolElem)i;
                if(m_shortName == proto.getShortName())
                {
                    // Optionally if a protocolInfo is specified
                    // match on that as well.
                    if(proto.getProtocolInfo() != null &&
                            proto.getProtocolInfo()._strip().length > 0)
                    {
                        if(proto.getProtocolInfo() == m_protocolInfo)
                        {
                            result = true;
                            break;
                        }
                    }
                    else
                    {
                        result = true;
                        break;
                    }
                }
            }
            
            return result;
        }

        public override string toUIListing(Gee.ArrayList<FilterEntry> filters)
        {
            XMLFragment elements = new XMLFragment();
            if((m_shortName != null) && (filtersMatch(filters, SHORT_NAME, m_shortName)))
            {
                protoPresent = true;
            }

            if((m_protocolInfo != null) && (filtersMatch(filters, PROTOCOL_INFO, m_protocolInfo)))
            {
                elements.addElement(PROTOCOL_INFO, m_protocolInfo);
                protoPresent = true;
            }
            
            StringBuilder sb = new StringBuilder("<" + PROTOCOL + " " + SHORT_NAME + "=\""  + m_shortName + "\">\n");
            if(m_uris.size > 0)
            {
                foreach (string i in m_uris) 
                {
                    sb.append("<").append(URI).append(">")
                    .append(i)
                    .append("</").append(URI).append(">\n");
                }
            }
            sb.append(elements.toXML());
            sb.append("</" + PROTOCOL + ">\n");
            return sb.str;
        }
    }

    protected class UIElem : UIListing
    {
        private string m_uiId = null;
        private string m_name = null;
        private string m_description = null;
        private string m_fork = null;
        private string m_lifetime = null;
        private Gee.ArrayList<IconElem> m_icons ;
        private Gee.ArrayList<ProtocolElem> m_protocols;
        // Keeps a list of m_icons.size for each icon element.
        private static Gee.ArrayList<int> m_iconsSizeList = new ArrayList<int>();
        private static int UIElemNum = 0; 
        private bool iconsPresent = false; 
        public UIElem(Xml.Node* node) throws GLib.Error
        {
            m_icons = new ArrayList<IconElem> ();
            m_protocols = new ArrayList<ProtocolElem> ();

            if(node == null)
            {
                throw new GLib.Error(0, 0, "Node is Null");
            }
            // invalid XML exception?
            for (Xml.Node* childNode = node->children; childNode != null; childNode = childNode->next)
            {
                string nodeName = childNode->name;
                if(UIID == nodeName)
                {
                    m_uiId = childNode->get_content();
                }
                else if (NAME == nodeName)
                {
                    m_name = childNode->get_content();
                }
                else if (DESCRIPTION == nodeName)
                {
                    m_description = childNode->get_content();
                }
                else if (ICONLIST == nodeName)
                {
                    for (Xml.Node* pNode = childNode->children; pNode != null; pNode = pNode->next)
                    {
                        if(ICON == pNode->name)
                        {
                            m_icons.add(new IconElem(pNode));
                            iconsPresent = true;
                        }
                    }
                    m_iconsSizeList.add(m_icons.size);                        
                }
                else if (FORK == nodeName)
                {
                    m_fork = childNode->get_content();
                }
                else if (LIFETIME == nodeName)
                {
                    m_lifetime = childNode->get_content();
                }
                else if (PROTOCOL == nodeName)
                {
                    m_protocols.add(new ProtocolElem(childNode));
                }
                else
                {
                    throw new GLib.Error(0, 0, "Bad XML element");
                }
            }
            if (iconsPresent != true)
            {
                m_iconsSizeList.add(0);                        
            }
        }

        public override bool match(Gee.ArrayList<ProtocolElem> protocols, Gee.ArrayList<FilterEntry> filters)
        {
            if(protocols == null || protocols.size == 0)
            {
                return true;
            }
            
            bool result = false;
            foreach (ProtocolElem prot in protocols)
            {
                ProtocolElem proto = (ProtocolElem)prot;
                if(proto.match(protocols, filters))
                {
                    result = true;
                    break;
                }
            }
            
            return result;
        }
        
        public override string toUIListing(Gee.ArrayList<FilterEntry> filters)
        {
            XMLFragment elements = new XMLFragment();
            bool atleastOne = false;
            elements.addElement(UIID, m_uiId);
            elements.addElement(NAME, m_name);
            
            if((m_name != null) && (filtersMatch(filters, NAME, m_name)))
            {
                atleastOne = true;
            }
            if((m_description != null) && (filtersMatch(filters, DESCRIPTION, m_description)))
            {
                elements.addElement(DESCRIPTION, m_description);
                atleastOne = true;
            }
            if((m_fork != null) && (filtersMatch(filters, FORK, m_fork)))
            {
                elements.addElement(FORK, m_fork);
                atleastOne = true;
            }
            if((m_lifetime != null) && (filtersMatch(filters, LIFETIME, m_lifetime)))
            {
                elements.addElement(LIFETIME, m_lifetime);
                atleastOne = true;
            }
            
            StringBuilder sb = new StringBuilder("<" + UI + ">\n");
            sb.append(elements.toXML());

            // Include icons
            if(m_iconsSizeList.get(UIElemNum++) > 0)
            {
                StringBuilder iconSB = new StringBuilder();
                foreach (IconElem i in m_icons)
                {
                    IconElem icon = (IconElem)i;
                    iconSB.append(icon.toUIListing(filters));
                }
                
                // Only display list if there is something to display
                if(iconSB.str.length > 0)
                {
                    atleastOne = true;
                    sb.append("<" + ICONLIST + ">\n");
                    sb.append(iconSB.str);
                    sb.append("</" + ICONLIST + ">\n");
                }
            }
            if(m_protocols.size > 0)
            {
                foreach(ProtocolElem i in m_protocols)
                {
                    ProtocolElem p = (ProtocolElem)i;
                    sb.append(p.toUIListing(filters));
                }
            }
            
            sb.append("</" + UI + ">\n");
            if ((atleastOne == true) || (protoPresent == true))
            {
                protoPresent = false;
                return sb.str;
            }
            else
            {
                return "";
            }
        }
    }
    
    internal class XMLFragment
    {
        public HashMap <string, string> elements;
        public ArrayList <string> keys;
        public XMLFragment()
        {
            elements = new HashMap <string,string> ();
            keys = new ArrayList <string> ();
        }
        public void addElement(string name, string value)
        {
            elements.set(name, value);
            keys.add(name);
        }
        
        public string toXML()
        {
            StringBuilder sb = new StringBuilder();
            foreach (var key in keys) {
                sb.append("<").append(key).append(">")
                .append(elements.get(key))
                .append("</").append(key).append(">\n");
            }
            return sb.str;
        }
        
        public int size()
        {
            return elements.size;
        }
    }
} // RygelServiceManager class
