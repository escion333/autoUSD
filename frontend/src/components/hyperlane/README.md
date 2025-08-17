# Hyperlane UI Components

This directory contains React components for monitoring and managing Hyperlane cross-chain messaging in the autoUSD application.

## Components

### 1. HyperlaneMessageTracker

Displays and tracks Hyperlane cross-chain messages with real-time status updates.

**Features:**
- Message status indicators (pending, dispatched, delivered, failed)
- Hyperlane explorer links for each message
- IGP (Interchain Gas Payment) details
- Retry functionality for failed messages
- Auto-refresh capability
- Transaction links to chain explorers

**Usage:**
```tsx
import { HyperlaneMessageTracker } from '@/components/hyperlane';

<HyperlaneMessageTracker
  messages={messages}
  onRetry={handleRetryMessage}
  autoRefresh={true}
  refreshInterval={10000}
/>
```

### 2. CrossChainStatus

Comprehensive dashboard for monitoring cross-chain infrastructure health and performance.

**Features:**
- Real-time chain synchronization status
- APY updates from child vaults
- Rebalancing progress indicators
- Chain health monitoring (healthy, degraded, offline)
- TVL and utilization metrics
- Auto-refresh with configurable intervals

**Usage:**
```tsx
import { CrossChainStatus } from '@/components/hyperlane';

<CrossChainStatus
  chains={chainStatuses}
  rebalancingStatus={rebalancingInfo}
  vaultAPYs={apyData}
  onRefresh={handleRefresh}
  autoRefresh={true}
  refreshInterval={15000}
/>
```

### 3. EmergencyControls

Administrative controls for emergency pause/unpause operations across all chains.

**Features:**
- Emergency pause button with reason input
- Hyperlane message propagation tracking
- Per-chain pause confirmation status
- Unpause functionality
- Retry mechanism for failed pause messages
- Test mode for demonstration

**Usage:**
```tsx
import { EmergencyControls } from '@/components/hyperlane';

<EmergencyControls
  chainStatuses={pauseStatuses}
  activeEmergency={emergencyMessage}
  onPause={handleEmergencyPause}
  onUnpause={handleEmergencyUnpause}
  onRetryMessage={handleRetryMessage}
  isOwner={true}
  testMode={false}
/>
```

## Demo Page

A complete demonstration of all Hyperlane components is available at `/hyperlane-demo`.

To run the demo:
1. Start the development server: `npm run dev`
2. Navigate to: `http://localhost:3000/hyperlane-demo`

The demo includes:
- Interactive controls to simulate various scenarios
- Mock data for all component states
- Rebalancing simulation
- Emergency pause/unpause flow
- Message lifecycle demonstration

## Types

All components export their TypeScript interfaces for proper type safety:

```tsx
import type {
  HyperlaneMessage,
  ChainStatus,
  RebalancingStatus,
  VaultAPY,
  ChainPauseStatus,
  EmergencyMessage
} from '@/components/hyperlane';
```

## Integration with Smart Contracts

These components are designed to work with the Hyperlane V3 protocol and the autoUSD smart contracts:

1. **Message Tracking**: Connects to Hyperlane Mailbox contracts for message status
2. **Chain Status**: Monitors MotherVault and ChildVault contracts across chains
3. **Emergency Controls**: Interacts with pause functionality in all vault contracts

## Styling

All components use the existing UI component library (`@/components/ui`) and follow the design system established in the application. They are fully responsive and support both light and dark modes (when implemented).

## Dependencies

- `react`: Core React library
- `date-fns`: Date formatting utilities
- `lucide-react`: Icon library
- Custom UI components from `@/components/ui`

## Future Enhancements

- WebSocket support for real-time message updates
- Integration with Hyperlane SDK for direct contract interaction
- Historical message filtering and search
- Export functionality for audit logs
- Advanced analytics and charts
- Multi-signature support for emergency operations