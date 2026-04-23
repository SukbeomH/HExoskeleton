# Stub Detection Patterns

## Universal Stub Patterns

```bash
# Comment-based stubs
grep -r -E "TODO|FIXME|XXX|HACK|PLACEHOLDER" .

# Placeholder text
grep -r -E "placeholder|lorem ipsum|coming soon" .

# Empty implementations
grep -r -E "return null|return undefined|return \{\}|return \[\]" .
```

## React Component Stubs

```javascript
// RED FLAGS:
return <div>Component</div>
return <div>Placeholder</div>
return <div>{/* TODO */}</div>
return null
return <></>

// Empty handlers:
onClick={() => {}}
onChange={() => console.log('clicked')}
onSubmit={(e) => e.preventDefault()}  // Only prevents default
```

## API Route Stubs

```typescript
// RED FLAGS:
export async function POST() {
  return Response.json({ message: "Not implemented" });
}

export async function GET() {
  return Response.json([]);  // Empty array, no DB query
}

// Console log only:
export async function POST(req) {
  console.log(await req.json());
  return Response.json({ ok: true });
}
```

## Wiring Red Flags

```typescript
// Fetch exists but response ignored:
fetch('/api/messages')  // No await, no .then

// Query exists but result not returned:
await prisma.message.findMany()
return Response.json({ ok: true })  // Returns static, not query

// Handler only prevents default:
onSubmit={(e) => e.preventDefault()}

// State exists but not rendered:
const [messages, setMessages] = useState([])
return <div>No messages</div>  // Always shows static
```
