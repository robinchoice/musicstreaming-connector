CREATE TABLE "feedback" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"kind" varchar(10) NOT NULL,
	"message" text NOT NULL,
	"email" varchar(255),
	"screenshot" "bytea",
	"context" jsonb NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "rate_limits" (
	"key" varchar(300) PRIMARY KEY NOT NULL,
	"count" integer NOT NULL,
	"reset_at" timestamp NOT NULL
);
